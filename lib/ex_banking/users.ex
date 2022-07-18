defmodule ExBanking.Users do
  @moduledoc """
  `ExBanking.Users` provides sets of functions to manage user related data in the bank.
  """
  alias ExBanking.{UserManager, UserRegistry}
  alias ExBanking.Users.UserSupervisor

  defguard is_valid_user(user) when is_binary(user) and user != ""

  defp create_user_supervisor_process(user),
    do: DynamicSupervisor.start_child(UserManager, {UserSupervisor, user})

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
  @spec create_user(user :: String.t()) ::
          {:ok, pid} | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_valid_user(user) do
    case create_user_supervisor_process(user) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:shutdown, {:failed_to_start_child, _, {:already_started, _}}}} ->
        {:error, :user_already_exists}
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @doc """
  Get a process pid of a user. Return nil if the user does not exist.

  ## Examples

      iex> get_user_pid("user")
      {:ok, #PID<0.106.0>}

      iex> get_user_pid("non_existing_user")
      {:ok, nil}

      iex> get_user_pid("")
      {:error, :wrong_arguments}

      iex> get_user_pid(:user)
      {:error, :wrong_arguments}

  """
  @spec get_user_pid(user :: String.t()) ::
          {:ok, pid | nil} | {:error, :wrong_arguments}
  def get_user_pid(user) when is_valid_user(user) do
    case Registry.lookup(UserRegistry, user) do
      [] -> {:ok, nil}
      [{pid, _}] -> {:ok, pid}
    end
  end

  def get_user_pid(_user), do: {:error, :wrong_arguments}
end
