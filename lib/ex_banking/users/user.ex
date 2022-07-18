defmodule ExBanking.Users.User do
  @moduledoc false
  use GenServer

  defmodule State do
    defstruct pending_ops: 0
  end

  ##########
  # Client #
  ##########

  def start_link(user),
    do: GenServer.start_link(__MODULE__, %State{}, name: via(user))

  def enqueue_operation(user),
    do: GenServer.call(via(user), :enqueue_operation)

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
