defmodule Pgpeek.Schemas.QueryStat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "query_stats" do
    field(:query_id, :string)
    field(:query_text, :string)
    field(:calls, :integer)
    field(:mean_exec_time, :float)
    field(:total_exec_time, :float)
    field(:min_exec_time, :float)
    field(:max_exec_time, :float)
    field(:stddev_exec_time, :float)
    field(:rows, :integer)
    field(:shared_blks_hit, :integer)
    field(:shared_blks_read, :integer)

    belongs_to(:snapshot, Pgpeek.Schemas.Snapshot)
  end

  def changeset(query_stat, attrs) do
    query_stat
    |> cast(attrs, [
      :query_id,
      :query_text,
      :calls,
      :mean_exec_time,
      :total_exec_time,
      :min_exec_time,
      :max_exec_time,
      :stddev_exec_time,
      :rows,
      :shared_blks_hit,
      :shared_blks_read,
      :snapshot_id
    ])
    |> validate_required([:query_id, :snapshot_id])
  end
end
