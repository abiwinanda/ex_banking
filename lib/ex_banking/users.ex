defmodule ExBanking.Users do
  @moduledoc """
  TODO
  """
  alias ExBanking.{UserManager, UserRegistry}
  alias ExBanking.Users.UserSupervisor

  defguard is_valid_user(user) when is_binary(user) and user != ""

  defp create_user_supervisor_process(user),
    do: DynamicSupervisor.start_child(UserManager, {UserSupervisor, user})

  @doc """
  TODO
  """
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
  TODO
  """
  def get_user_pid(user) when is_valid_user(user) do
    case Registry.lookup(UserRegistry, user) do
      [] -> {:ok, nil}
      [{pid, _}] -> {:ok, pid}
    end
  end

  def get_user_pid(_user), do: {:error, :wrong_arguments}
end
