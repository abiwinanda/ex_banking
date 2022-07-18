defmodule ExBanking do
  @moduledoc """
  TODO
  """

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
  def create_user(_user) do
  end

  @doc """
  TODO
  """
  @spec deposit(user, amount, currency) :: {:ok, new_balance :: number} | deposit_error
  def deposit(_user, _amount, _currency) do
  end

  @doc """
  TODO
  """
  @spec withdraw(user, amount, currency) :: {:ok, new_balance :: number} | withdraw_error
  def withdraw(_user, _amount, _currency) do
  end

  @doc """
  TODO
  """
  @spec get_balance(user, currency) :: {:ok, balance :: number} | get_balance_error
  def get_balance(_user, _currency) do
  end

  @doc """
  TODO
  """
  @spec send(from_user :: user, to_user :: user, amount, currency) ::
          {:ok, from_user_balance :: number, to_user_balance :: number} | send_error
  def send(_from_user, _to_user, _amount, _currency) do
  end
end
