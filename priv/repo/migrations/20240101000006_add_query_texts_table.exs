defmodule Pgpeek.Repo.Migrations.AddQueryTextsTable do
  use Ecto.Migration

  def change do
    create table(:query_texts) do
      add :query_id, :string, null: false
      add :query_text, :text
      add :first_seen_at, :utc_datetime, null: false
    end

    create unique_index(:query_texts, [:query_id])
  end
end
