defmodule ElixirLearningApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixirLearningAppWeb.Telemetry,
      ElixirLearningApp.Repo,
      {DNSCluster, query: Application.get_env(:elixir_learning_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirLearningApp.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ElixirLearningApp.Finch},
      # Start a worker by calling: ElixirLearningApp.Worker.start_link(arg)
      # {ElixirLearningApp.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixirLearningAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirLearningApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirLearningAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
