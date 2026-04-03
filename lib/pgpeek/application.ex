defmodule Pgpeek.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Start Repo first, run migrations, then start everything else.
    # SnapshotWorker queries SQLite on init, so tables must exist.
    {:ok, _} = Pgpeek.Repo.start_link([])
    migrate!()
    Pgpeek.Auth.seed_admin_user!()

    children = [
      Pgpeek.ProbeRepo,
      PgpeekWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:pgpeek, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pgpeek.PubSub},
      Pgpeek.SnapshotWorker,
      PgpeekWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Pgpeek.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PgpeekWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp migrate! do
    Ecto.Migrator.run(Pgpeek.Repo, migrations_path(), :up, all: true)
  end

  defp migrations_path do
    Application.app_dir(:pgpeek, "priv/repo/migrations")
  end
end
