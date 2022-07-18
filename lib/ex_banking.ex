defmodule ExBanking do
  @moduledoc """
  TODO
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
  TODO
  """
  @spec create_user(user) :: :ok | create_user_error
  def create_user(user) do
    with {:create_user, {:ok, _}} <-
           {:create_user, Users.create_user(user)} do
      :ok
    else
      {:create_user, error} ->
        error
    end
  end

  @doc """
  TODO
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

      {:does_user_exist, error} ->
        error

      {:deposit, error} ->
        error
    end
  end

  @doc """
  TODO
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

      {:does_user_exist, error} ->
        error

      {:withdraw, error} ->
        error
    end
  end

  @doc """
  TODO
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

      {:does_user_exist, error} ->
        error

      {:get_balance, error} ->
        error
    end
  end

  @doc """
  TODO
  """
  @spec send(from_user :: user, to_user :: user, amount, currency) ::
          {:ok, from_user_balance :: number, to_user_balance :: number} | send_error
  def send(from_user, to_user, amount, currency) do
    with {:does_sender_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_sender_exist, Users.get_user_pid(from_user)},
         {:does_receiver_exist, {:ok, pid}} when is_pid(pid) <-
           {:does_receiver_exist, Users.get_user_pid(from_user)},
         {:send_balance, {:ok, sender_new_balance, receiver_new_balance}} <-
           {:send_balance, Accounts.send(from_user, to_user, amount, currency)} do
      {:ok, sender_new_balance, receiver_new_balance}
    else
      {:does_sender_exist, {:ok, nil}} ->
        {:error, :sender_does_not_exist}

      {:does_sender_exist, error} ->
        error

      {:does_receiver_exist, {:ok, nil}} ->
        {:error, :receiver_does_not_exist}

      {:does_receiver_exist, error} ->
        error

      {:send_balance, error} ->
        error
    end
  end
end
