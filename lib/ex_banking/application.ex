defmodule ExBanking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ExBanking.UserRegistry},
      {Registry, keys: :unique, name: ExBanking.AccountRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.UserManager},
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.AccountManager}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
