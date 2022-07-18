defmodule ExBanking.Accounts do
  @moduledoc """
  `ExBanking.Users` provides sets of functions to manage user's account related data in the bank.
  """
  alias ExBanking.AccountManager
  alias ExBanking.Users.User
  alias ExBanking.Accounts.{AccountSupervisor, Account}

  @type user :: String.t()
  @type currency :: String.t()
  @type amount :: number
  @type deposit_error ::
          {:error,
           :wrong_arguments
           | :too_many_requests_to_user}
  @type withdraw_error ::
          {:error,
           :wrong_arguments
           | :not_enough_money
           | :too_many_requests_to_user}
  @type get_balance_error ::
          {:error,
           :wrong_arguments
           | :too_many_requests_to_user}
  @type send_error ::
          {:error,
           :wrong_arguments
           | :not_enough_money
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  defguard is_valid_user(user) when is_binary(user) and user != ""
  defguard is_valid_currency(currency) when is_binary(currency) and currency != ""

  defguard is_valid_amount(amount, currency)
           when is_number(amount) and amount > 0 and is_binary(currency) and currency != ""

  defp create_account_supervisor_process(user, currency),
    do:
      DynamicSupervisor.start_child(
        AccountManager,
        {AccountSupervisor, user: user, amount: 0, currency: currency}
      )

  @doc """
  Deposit money of a specific currency to a user's account. If the account is not yet exists,
  a new account will be created automatically. The account new balance will be returned on success
  and it will always be rounded to two decimal places down.

  ## Examples

      iex> deposit("user", 500.505, "EUR")
      {:ok, 500.50}

      iex> deposit("user", 123.123, "IDR")
      {:ok, 123.12}

      iex> deposit("user", "500.505", "EUR")
      {:error, :wrong_arguments}

  """
  @spec deposit(user, amount, currency) :: {:ok, new_balance :: number} | deposit_error
  def deposit(user, amount, currency)
      when is_valid_user(user) and is_valid_amount(amount, currency) do
    with {:ensure_currency_account_exists, _} <-
           {:ensure_currency_account_exists, create_account_supervisor_process(user, currency)},
         {:enqueue_operation, {:ok, _}} <-
           {:enqueue_operation, User.enqueue_operation(user)},
         {:deposit, {:ok, new_balance}} <-
           {:deposit, Account.deposit(user, amount, currency)},
         {:dequeue_operation, {:ok, _}} <-
           {:dequeue_operation, User.dequeue_operation(user)} do
      {:ok, new_balance}
    else
      {:enqueue_operation, _} ->
        {:error, :too_many_requests_to_user}

      {:deposit, error} ->
        error
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
  Withdraw money of a specific currency from a user's account. If the account is not yet exists,
  the balance will be assumed 0 and `:not_enough_money` error will be returned. The account new balance
  will be returned on success and it will always be rounded to two decimal places down.

  ## Examples

      iex> withdraw("user", 100, "EUR")
      {:ok, 400.50}

      iex> withdraw("user", 5000, "IDR")
      {:error, :not_enough_money}

      iex> withdraw("user", 5000, "NON_EXISTING_CURRENCY")
      {:error, :not_enough_money}

      iex> withdraw("user", "500", "EUR")
      {:error, :wrong_arguments}

  """
  @spec withdraw(user, amount, currency) :: {:ok, new_balance :: number} | withdraw_error
  def withdraw(user, amount, currency)
      when is_valid_user(user) and is_valid_amount(amount, currency) do
    with {:enqueue_operation, {:ok, _}} <-
           {:enqueue_operation, User.enqueue_operation(user)},
         {:does_account_exists, true} <-
           {:does_account_exists, Account.does_account_exist?(user, currency)},
         {:withdraw, {:ok, new_balance}} <-
           {:withdraw, Account.withdraw(user, amount, currency)},
         {:dequeue_operation, {:ok, _}} <-
           {:dequeue_operation, User.dequeue_operation(user)} do
      {:ok, new_balance}
    else
      {:enqueue_operation, _} ->
        {:error, :too_many_requests_to_user}

      {:does_account_exists, false} ->
        {:error, :not_enough_money}

      {:withdraw, error} ->
        error
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
  Get balance of a specific currency from a user's account. If the account is not yet exists,
  0 will be returned. The account balance will always be rounded to two decimal places down.

  ## Examples

      iex> get_balance("user", "EUR")
      {:ok, 400.50}

      iex> get_balance("user", "NON_EXISTING_CURRENCY")
      {:ok, 0}

      iex> get_balance("user", :EUR)
      {:error, :wrong_arguments}

  """
  @spec get_balance(user, currency) :: {:ok, new_balance :: number} | get_balance_error
  def get_balance(user, currency)
      when is_valid_user(user) and is_valid_currency(currency) do
    with {:enqueue_operation, {:ok, _}} <-
           {:enqueue_operation, User.enqueue_operation(user)},
         {:does_account_exists, true} <-
           {:does_account_exists, Account.does_account_exist?(user, currency)},
         {:get_balance, {:ok, balance}} <-
           {:get_balance, Account.get_balance(user, currency)},
         {:dequeue_operation, {:ok, _}} <-
           {:dequeue_operation, User.dequeue_operation(user)} do
      {:ok, balance}
    else
      {:enqueue_operation, _} ->
        {:error, :too_many_requests_to_user}

      {:does_account_exists, false} ->
        {:ok, 0}

      {:get_balance, error} ->
        error
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @doc """
  Send money from a sender's account to a receiver's account. If the sender tries to send money from an account
  that is not yet exists, the balance will be assumed 0 and `:not_enough_money` error will be returned. The sender
  and receiver new balance will be returned on success and they will always be rounded to two decimal places down.

  ## Examples

      iex> send("sender", "receiver", 500, "EUR")
      {:ok, 200.50, 600.30}

      iex> send("sender", "receiver", 5000, "EUR")
      {:error, :not_enough_money}

      iex> send("sender", "receiver", 5000, "NON_EXISTING_CURRENCY")
      {:error, :not_enough_money}

      iex> send("sender", "receiver", "500", "EUR")
      {:error, :wrong_arguments}

  """
  @spec send(from_user :: user, to_user :: user, amount, currency) ::
          {:ok, from_user_balance :: number, to_user_balance :: number} | send_error
  def send(from_user, to_user, amount, currency)
      when is_valid_user(from_user) and is_valid_user(to_user) and
             is_valid_amount(amount, currency) do
    with {:enqueue_from_user_operation, {:ok, _}} <-
           {:enqueue_from_user_operation, User.enqueue_operation(from_user)},
         {:enqueue_to_user_operation, {:ok, _}} <-
           {:enqueue_to_user_operation, User.enqueue_operation(to_user)},
         {:ensure_sender_account_exists, _} <-
           {:ensure_sender_account_exists, create_account_supervisor_process(from_user, currency)},
         {:ensure_receiver_account_exists, _} <-
           {:ensure_receiver_account_exists, create_account_supervisor_process(to_user, currency)},
         {:withdraw_sender, {:ok, sender_new_balance}} <-
           {:withdraw_sender, Account.withdraw(from_user, amount, currency)},
         {:deposit_receiver, {:ok, receiver_new_balance}} <-
           {:deposit_receiver, Account.deposit(to_user, amount, currency)},
         {:dequeue_from_user_operation, {:ok, _}} <-
           {:dequeue_from_user_operation, User.dequeue_operation(from_user)},
         {:dequeue_to_user_operation, {:ok, _}} <-
           {:dequeue_to_user_operation, User.dequeue_operation(to_user)} do
      {:ok, sender_new_balance, receiver_new_balance}
    else
      {:enqueue_from_user_operation, _error} ->
        {:error, :too_many_requests_to_sender}

      {:enqueue_to_user_operation, _error} ->
        {:error, :too_many_requests_to_receiver}

      {:withdraw_sender, error} ->
        error

      {:deposit_receiver, error} ->
        error
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}
end
