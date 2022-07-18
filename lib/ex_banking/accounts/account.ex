defmodule ExBanking.Accounts.Account do
  @moduledoc false
  use GenServer
  require Decimal
  alias ExBanking.AccountRegistry

  defmodule State do
    defstruct balance: Decimal.new(0)
  end

  ##########
  # Client #
  ##########

  def start_link(args) do
    GenServer.start_link(
      __MODULE__,
      %State{balance: to_decimal(args[:amount])},
      name: via(args[:user], args[:currency])
    )
  end

  def deposit(user, amount, currency),
    do: GenServer.call(via(user, currency), {:deposit, amount})

  def withdraw(user, amount, currency),
    do: GenServer.call(via(user, currency), {:withdraw, amount})

  def get_balance(user, currency),
    do: GenServer.call(via(user, currency), :get_balance)

  def does_account_exist?(user, currency) do
    case Registry.lookup(AccountRegistry, "#{user}:#{currency}") do
      [] -> false
      _ -> true
    end
  end

  ##########
  # Server #
  ##########

  def init(args) do
    {:ok, args}
  end

  def handle_call({:deposit, amount}, _from, %State{balance: balance} = state) do
    new_balance = Decimal.add(balance, to_decimal(amount))
    {:reply, {:ok, decimal_to_float(new_balance)}, %State{state | balance: new_balance}}
  end

  def handle_call({:withdraw, amount}, _from, %State{balance: balance} = state) do
    new_balance = Decimal.sub(balance, to_decimal(amount))

    case Decimal.negative?(new_balance) do
      false ->
        {:reply, {:ok, decimal_to_float(new_balance)}, %State{state | balance: new_balance}}

      true ->
        {:reply, {:error, :not_enough_money}, state}
    end
  end

  def handle_call(:get_balance, _from, %State{balance: balance} = state),
    do: {:reply, {:ok, decimal_to_float(balance)}, state}

  ###########
  # Helpers #
  ###########

  defp to_decimal(amount) when is_integer(amount), do: Decimal.new(amount)
  defp to_decimal(amount) when is_float(amount), do: Decimal.from_float(amount)
  defp to_decimal(amount), do: amount

  defp decimal_to_float(amount), do: amount |> Decimal.round(2, :down) |> Decimal.to_float()

  defp via(user, currency),
    do: {:via, Registry, {AccountRegistry, "#{user}:#{currency}"}}
end
