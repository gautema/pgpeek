defmodule Pgpeek.Repo.Migrations.CreateSystemStats do
  use Ecto.Migration

  def change do
    create table(:system_stats) do
      add :snapshot_id, references(:snapshots, on_delete: :delete_all), null: false
      add :cache_hit_ratio, :float
      add :total_connections, :integer
      add :active_connections, :integer
      add :idle_in_transaction, :integer
      add :max_connections, :integer
      add :replication_lag_bytes, :integer
      add :temp_bytes, :integer
      add :deadlocks, :integer
      add :wal_bytes, :integer
      add :checkpoints_timed, :integer
      add :checkpoints_requested, :integer
      add :buffers_checkpoint, :integer
      add :tx_wraparound_age, :integer
      add :database_size_bytes, :integer
    end

    create index(:system_stats, [:snapshot_id])
  end
end
