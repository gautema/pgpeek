defmodule Pgpeek.Repo.Migrations.CreateDeploys do
  use Ecto.Migration

  def change do
    create table(:deploys) do
      add :description, :text
      add :deployed_at, :utc_datetime, null: false
    end

    create index(:deploys, [:deployed_at])
  end
end
