defmodule Pgpeek.Repo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts) do
      add :metric, :string, null: false
      add :threshold, :float, null: false
      add :channel, :string, null: false
      add :destination, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
