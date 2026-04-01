defmodule Pgpeek.Repo.Migrations.CreateQueryStats do
  use Ecto.Migration

  def change do
    create table(:query_stats) do
      add :snapshot_id, references(:snapshots, on_delete: :delete_all), null: false
      add :query_id, :string, null: false
      add :query_text, :text
      add :calls, :integer
      add :mean_exec_time, :float
      add :total_exec_time, :float
      add :min_exec_time, :float
      add :max_exec_time, :float
      add :stddev_exec_time, :float
      add :rows, :integer
      add :shared_blks_hit, :integer
      add :shared_blks_read, :integer
    end

    create index(:query_stats, [:snapshot_id])
    create index(:query_stats, [:query_id])
    create index(:query_stats, [:snapshot_id, :query_id])
  end
end
