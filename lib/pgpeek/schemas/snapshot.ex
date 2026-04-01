defmodule Pgpeek.Schemas.Snapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "snapshots" do
    field :captured_at, :utc_datetime
    field :stats_reset_at, :utc_datetime

    has_many :query_stats, Pgpeek.Schemas.QueryStat
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:captured_at, :stats_reset_at])
    |> validate_required([:captured_at])
  end
end
