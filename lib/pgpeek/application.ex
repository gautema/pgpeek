defmodule Pgpeek.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Pgpeek.Repo,
      Pgpeek.ProbeRepo,
      PgpeekWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:pgpeek, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pgpeek.PubSub},
      Pgpeek.SnapshotWorker,
      PgpeekWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Pgpeek.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Seed admin user on first boot
    Pgpeek.Auth.seed_admin_user!()

    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    PgpeekWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
