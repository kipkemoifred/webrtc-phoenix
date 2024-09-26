defmodule WebrtcPhoenix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WebrtcPhoenixWeb.Telemetry,
      WebrtcPhoenix.Repo,
      {DNSCluster, query: Application.get_env(:webrtc_phoenix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WebrtcPhoenix.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: WebrtcPhoenix.Finch},
      # Start a worker by calling: WebrtcPhoenix.Worker.start_link(arg)
      # {WebrtcPhoenix.Worker, arg},
      # Start to serve requests, typically the last entry
      WebrtcPhoenixWeb.Endpoint,
      {SessionManager, []}  # Ensure SessionManager is added here
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebrtcPhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WebrtcPhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
