defmodule ExBanking do
  @moduledoc """
  `ExBanking` provides a set of public APIs to create, get, deposit, withdraw, and send money.

  `ExBanking` consists out of two major components (or context): `Users` and `Accounts`. `Users`
  manages user related data in the bank such as create a new user or check if a user exists
  and `Accounts` manages currency related data that is modelled as an account.

  Each user in the bank is represented as a genserver process hence a bank with 10 users will have
  10 genserver processes. This is also the case for an account. The account process is used to store
  an account balance and the user process is used to limit the number concurrent operations within a single user.

  Since different users are represented by different processes (or actors), two operations to different users
  can be processed concurrently at the same time while multiple processes to a single user will be handled
  one at a time. This way, the user process can be used as a synchronization point to provide back-pressure for users.
  """
  alias ExBanking.{Users, Accounts}

  @type user :: String.t()
  @type currency :: String.t()
  @type amount :: number
  @type create_user_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists}
  @type deposit_error ::
          {:error,
           :wrong_arguments
           | :user_does_not_exist
           | :too_many_requests_to_user}
  @type withdraw_error ::
          {:error,
           :wrong_arguments
           | :user_does_not_exist
           | :not_enough_money
           | :too_many_requests_to_user}
  @type get_balance_error ::
          {:error,
           :wrong_arguments
           | :user_does_not_exist
           | :too_many_requests_to_user}
  @type send_error ::
          {:error,
           :wrong_arguments
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  @doc """
  Create a new user. The user must be a non empty string.

  ## Examples

      iex> create_user("user")
      {:ok, #PID<0.106.0>}

      iex> create_user("user")
      {:error, :user_already_exists}

      iex> create_user("")
      {:error, :wrong_arguments}

      iex> create_user(:user)
      {:error, :wrong_arguments}

  """
  @spec create_user(user) :: :ok | create_user_error
  def create_user(user) do
    with {:create_user, {:ok, _}} <- {:create_user, Users.create_user(user)} do
      :ok
    else
      {:create_user, error} -> error
    end
  end

  @doc """
  Deposit money of a specific currency to a user's account. If the account is not yet exists,
  a new account will be created automatically. The account new balance will be returned on success
  and it will always be rounded to two decimal places down.

  ## Examples

      iex> deposit("user", 500.505, "EUR")
      {:ok, 500.50}

      iex> deposit("user", 123.123, "IDR")
      {:ok, 123.12}

      iex> deposit("non_existing_user", 100, "EUR")
      {:error, :user_does_not_exist}

      iex> deposit("user", "500.505", "EUR")
      {:error, :wrong_arguments}

  """
  @spec deposit(user, amount, currency) :: {:ok, new_balance :: number} | deposit_error
  def deposit(user, amount, currency) do
    with {:does_user_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_user_exist, Users.get_user_pid(user)},
         {:deposit, {:ok, new_balance}} <-
           {:deposit, Accounts.deposit(user, amount, currency)} do
      {:ok, new_balance}
    else
      {:does_user_exist, {:ok, nil}} ->
        {:error, :user_does_not_exist}

      {:deposit, error} ->
        error

      _ ->
        {:error, :wrong_arguments}
    end
  end

  @doc """
  Withdraw money of a specific currency from a user's account. If the account is not yet exists,
  the balance will be assumed 0 and `:not_enough_money` error will be returned. The account new balance
  will be returned on success and it will always be rounded to two decimal places down.

  ## Examples

      iex> withdraw("user", 100, "EUR")
      {:ok, 400.50}

      iex> withdraw("user", 5000, "IDR")
      {:error, :not_enough_money}

      iex> withdraw("user", 100, "NON_EXISTING_CURRENCY")
      {:error, :not_enough_money}

      iex> withdraw("non_existing_user", 100, "IDR")
      {:error, :user_does_not_exist}

      iex> withdraw("user", "500", "EUR")
      {:error, :wrong_arguments}

  """
  @spec withdraw(user, amount, currency) :: {:ok, new_balance :: number} | withdraw_error
  def withdraw(user, amount, currency) do
    with {:does_user_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_user_exist, Users.get_user_pid(user)},
         {:withdraw, {:ok, new_balance}} <-
           {:withdraw, Accounts.withdraw(user, amount, currency)} do
      {:ok, new_balance}
    else
      {:does_user_exist, {:ok, nil}} ->
        {:error, :user_does_not_exist}

      {:withdraw, error} ->
        error

      _ ->
        {:error, :wrong_arguments}
    end
  end

  @doc """
  Get balance of a specific currency from a user's account. If the account is not yet exists,
  0 will be returned. The account balance will always be rounded to two decimal places down.

  ## Examples

      iex> get_balance("user", "EUR")
      {:ok, 400.50}

      iex> get_balance("user", "NON_EXISTING_CURRENCY")
      {:ok, 0}

      iex> get_balance("non_existing_user", "EUR")
      {:error, :user_does_not_exist}

      iex> get_balance("user", :EUR)
      {:error, :wrong_arguments}

  """
  @spec get_balance(user, currency) :: {:ok, balance :: number} | get_balance_error
  def get_balance(user, currency) do
    with {:does_user_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_user_exist, Users.get_user_pid(user)},
         {:get_balance, {:ok, balance}} <-
           {:get_balance, Accounts.get_balance(user, currency)} do
      {:ok, balance}
    else
      {:does_user_exist, {:ok, nil}} ->
        {:error, :user_does_not_exist}

      {:get_balance, error} ->
        error

      _ ->
        {:error, :wrong_arguments}
    end
  end

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

      iex> send("non_existing_sender", "receiver", 10, "EUR")
      {:error, :sender_does_not_exist}

      iex> send("sender", "non_existing_receiver", 10, "EUR")
      {:error, :receiver_does_not_exist}

      iex> send("sender", "receiver", "500", "EUR")
      {:error, :wrong_arguments}

  """
  @spec send(from_user :: user, to_user :: user, amount, currency) ::
          {:ok, from_user_balance :: number, to_user_balance :: number} | send_error
  def send(from_user, to_user, amount, currency) do
    with {:does_sender_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_sender_exist, Users.get_user_pid(from_user)},
         {:does_receiver_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_receiver_exist, Users.get_user_pid(to_user)},
         {:send, {:ok, sender_new_balance, receiver_new_balance}} <-
           {:send, Accounts.send(from_user, to_user, amount, currency)} do
      {:ok, sender_new_balance, receiver_new_balance}
    else
      {:does_sender_exist, {:ok, nil}} ->
        {:error, :sender_does_not_exist}

      {:does_receiver_exist, {:ok, nil}} ->
        {:error, :receiver_does_not_exist}

      {:send, error} ->
        error

      _ ->
        {:error, :wrong_arguments}
    end
  end
end
