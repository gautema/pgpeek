defmodule Pgpeek.Schemas.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alerts" do
    field :metric, :string
    field :threshold, :float
    field :channel, :string
    field :destination, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:metric, :threshold, :channel, :destination])
    |> validate_required([:metric, :threshold, :channel, :destination])
  end
end
