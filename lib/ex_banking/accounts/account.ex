defmodule ExBanking.Accounts.Account do
  @moduledoc """
  `ExBanking.Accounts.Account` is a genserver process that represent an account entity in the bank. An account is owned by a user and only
  store one currency of a balance. i.e 3 account processes are required for a user to have 3 different currencies account (e.g "EUR", "USD", "NOK").

  `ExBanking.Accounts.Account` genserver process only has one state which is a `balance`. The currency of the account and user who owned it are used
  as the process name. By having different currency accounts in a separate process means that different accounts can operate independently or isolated
  from one another. This improves realiability incase one currency is more difficult and more error prone to handle than other currencies. The limit
  of operation to an account however is limited by the total number of operation to a user. In other words, if an account has no pending operation
  but the user who own account already has 10 pending operations to his/her other account, the account with no pending operation can't accept
  any request until the user's pending operation is less than 10.
  """
  use GenServer
  require Decimal
  alias ExBanking.AccountRegistry

  @type user :: String.t()
  @type currency :: String.t()
  @type amount :: number

  # used to simulate time to process an operation
  @processtime 100

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

  @doc """
  Deposit balance to a single currency account owned by a user and return the account's latest balance.

  ## Examples

      iex> deposit("user", 100.50, "EUR")
      {:ok, 100.50}

      iex> deposit("user", 100, "EUR")
      {:ok, 200.50}

      iex> deposit("user", 500.50, "IDR")
      {:ok, 500.50}

  """
  @spec deposit(user, amount, currency) :: {:ok, new_balance :: number}
  def deposit(user, amount, currency),
    do: GenServer.call(via(user, currency), {:deposit, amount})

  @doc """
  Withdraw balance from a single currency account owned by a user and return the account's latest balance.

  ## Examples

      iex> withdraw("user", 100, "EUR")
      {:ok, 100.50}

      iex> withdraw("user", 50, "EUR")
      {:ok, 50.50}

      iex> withdraw("user", 1000, "IDR")
      {:error, :not_enough_money}

  """
  @spec withdraw(user, amount, currency) ::
          {:ok, new_balance :: number} | {:error, :not_enough_money}
  def withdraw(user, amount, currency),
    do: GenServer.call(via(user, currency), {:withdraw, amount})

  @doc """
  Get balance of a single currency account owned by a user.

  ## Examples

      iex> get_balance("user", "EUR")
      {:ok, 50.50}

      iex> get_balance("user", "IDR")
      {:ok, 500.50}

      iex> get_balance("user", "NON_EXISTING_CURRENCY")
      {:ok, 0}

  """
  @spec get_balance(user, currency) :: {:ok, balance :: number}
  def get_balance(user, currency),
    do: GenServer.call(via(user, currency), :get_balance)

  @doc """
  Check if an account exists or not.

  ## Examples

      iex> does_account_exist?("user", "EUR")
      true

      iex> does_account_exist?("user", "IDR")
      true

      iex> does_account_exist("user", "NON_EXISTING_CURRENCY")
      false

  """
  @spec does_account_exist?(user, currency) :: boolean()
  def does_account_exist?(user, currency) do
    :timer.sleep(@processtime)

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

    :timer.sleep(@processtime)

    {:reply, {:ok, decimal_to_float(new_balance)}, %State{state | balance: new_balance}}
  end

  def handle_call({:withdraw, amount}, _from, %State{balance: balance} = state) do
    new_balance = Decimal.sub(balance, to_decimal(amount))

    :timer.sleep(@processtime)

    case Decimal.negative?(new_balance) do
      false ->
        {:reply, {:ok, decimal_to_float(new_balance)}, %State{state | balance: new_balance}}

      true ->
        {:reply, {:error, :not_enough_money}, state}
    end
  end

  def handle_call(:get_balance, _from, %State{balance: balance} = state) do
    :timer.sleep(@processtime)
    {:reply, {:ok, decimal_to_float(balance)}, state}
  end

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
