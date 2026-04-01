defmodule Pgpeek.Schemas.QueryText do
  use Ecto.Schema

  schema "query_texts" do
    field :query_id, :string
    field :query_text, :string
    field :first_seen_at, :utc_datetime
  end
end
