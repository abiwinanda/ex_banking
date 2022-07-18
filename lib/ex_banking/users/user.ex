defmodule ExBanking.Users.User do
  @moduledoc """
  `ExBanking.Users.User` is a genserver process that represent a user entity in the bank. i.e one user is represented by a single genserver process.

  `ExBanking.Users.User` genserver currently only has one state which is a `pending_ops` that tracks the number of
  pending operation for a single user. This genserver controls or limits the concurrency of operations within a user.
  You could think of this genserver as a synchronization point to provide back-pressure for a user. The limit of conccurency
  within a given time for a single user is currently max to 10 pending operations. Any incoming operation above this limit will be rejected.

  In order to extend the functionality of this genserver in the future, you could add more state later on.
  """
  use GenServer

  defmodule State do
    defstruct pending_ops: 0
  end

  ##########
  # Client #
  ##########

  def start_link(user),
    do: GenServer.start_link(__MODULE__, %State{}, name: via(user))

  @doc """
  Enqueue or increase the number of pending operations to a user. The maximum number of operation at a given time is 10,

  ## Examples

      iex> enqueue_operation("user")
      {:ok, 1}

      iex> enqueue_operation("user")
      {:error, :too_many_requests_to_user}

  """
  @spec enqueue_operation(user :: String.t()) ::
          {:ok, pending_ops :: number} | {:error, :too_many_requests_to_user}
  def enqueue_operation(user),
    do: GenServer.call(via(user), :enqueue_operation)

  @doc """
  Dequeue or decrease the number of pending operations to a user.

  ## Examples

      iex> dequeue_operation("user")
      {:ok, 2}

      iex> dequeue_operation("user")
      {:ok, 1}

      iex> dequeue_operation("user")
      {:ok, 0}

      iex> dequeue_operation("user")
      {:ok, 0}

  """
  @spec dequeue_operation(user :: String.t()) :: {:ok, pending_ops :: number}
  def dequeue_operation(user),
    do: GenServer.call(via(user), :dequeue_operation)

  ##########
  # Server #
  ##########

  def init(state),
    do: {:ok, state}

  def handle_call(:enqueue_operation, _from, %State{pending_ops: pending_ops} = state)
      when pending_ops < 10,
      do: {:reply, {:ok, pending_ops + 1}, %State{state | pending_ops: pending_ops + 1}}

  def handle_call(:enqueue_operation, _from, state),
    do: {:reply, {:error, :too_many_requests_to_user}, state}

  def handle_call(:dequeue_operation, _from, %State{pending_ops: pending_ops} = state)
      when pending_ops > 0,
      do: {:reply, {:ok, pending_ops - 1}, %State{state | pending_ops: pending_ops - 1}}

  def handle_call(:dequeue_operation, _from, state),
    do: {:reply, {:ok, 0}, %State{state | pending_ops: 0}}

  defp via(name),
    do: {:via, Registry, {ExBanking.UserRegistry, name}}
end
