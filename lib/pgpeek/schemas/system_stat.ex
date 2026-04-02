defmodule Pgpeek.Schemas.SystemStat do
  use Ecto.Schema

  schema "system_stats" do
    field(:cache_hit_ratio, :float)
    field(:total_connections, :integer)
    field(:active_connections, :integer)
    field(:idle_in_transaction, :integer)
    field(:max_connections, :integer)
    field(:replication_lag_bytes, :integer)
    field(:temp_bytes, :integer)
    field(:deadlocks, :integer)
    field(:wal_bytes, :integer)
    field(:checkpoints_timed, :integer)
    field(:checkpoints_requested, :integer)
    field(:buffers_checkpoint, :integer)
    field(:tx_wraparound_age, :integer)
    field(:database_size_bytes, :integer)

    belongs_to(:snapshot, Pgpeek.Schemas.Snapshot)
  end
end
