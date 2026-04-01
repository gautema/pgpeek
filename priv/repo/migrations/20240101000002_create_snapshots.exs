defmodule Pgpeek.Repo.Migrations.CreateSnapshots do
  use Ecto.Migration

  def change do
    create table(:snapshots) do
      add :captured_at, :utc_datetime, null: false
      add :stats_reset_at, :utc_datetime
    end

    create index(:snapshots, [:captured_at])
  end
end
