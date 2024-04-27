defmodule Microsearch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MicrosearchWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:microsearch, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Microsearch.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Microsearch.Finch},
      # Start a worker by calling: Microsearch.Worker.start_link(arg)
      # {Microsearch.Worker, arg},
      # Start to serve requests, typically the last entry
      MicrosearchWeb.Endpoint,
      Supervisor.child_spec({Cachex, name: :documents}, id: :documents),
      Supervisor.child_spec({Cachex, name: :index}, id: :index),
      Supervisor.child_spec({Cachex, name: :avdl}, id: :avdl),
      {Microsearch.SearchEngine, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Microsearch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MicrosearchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
