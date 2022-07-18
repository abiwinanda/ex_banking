defmodule ExBanking.Accounts.AccountSupervisor do
  @moduledoc false

  # :temporary restart is used so that whenever a child process of AccountSupervisor
  # is consistently crashing and causing the AccountSupervisor to exit, the exit will be trapped
  # and leave the parent process (AccountManager) to keep running.
  use Supervisor, restart: :temporary

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(args) do
    children = [
      {ExBanking.Accounts.Account, args}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
