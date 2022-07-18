defmodule ExBanking.Accounts do
  @moduledoc """
  TODO
  """
  alias ExBanking.AccountManager
  alias ExBanking.Users.User
  alias ExBanking.Accounts.{AccountSupervisor, Account}

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
  TODO
  """
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
  TODO
  """
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
  TODO
  """
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
  TODO
  """
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
