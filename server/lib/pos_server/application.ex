defmodule PosServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PosServerWeb.Telemetry,
      PosServer.Repo,
      {DNSCluster, query: Application.get_env(:pos_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PosServer.PubSub},
      PosServerWeb.Presence,
      # Start a worker by calling: PosServer.Worker.start_link(arg)
      # {PosServer.Worker, arg},
      # Start to serve requests, typically the last entry
      PosServerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PosServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PosServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
