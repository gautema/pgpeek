defmodule Pgpeek.Schemas.Deploy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "deploys" do
    field :description, :string
    field :deployed_at, :utc_datetime
  end

  def changeset(deploy, attrs) do
    deploy
    |> cast(attrs, [:description, :deployed_at])
    |> validate_required([:deployed_at])
  end
end
