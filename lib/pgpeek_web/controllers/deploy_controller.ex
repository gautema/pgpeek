defmodule PgpeekWeb.DeployController do
  use PgpeekWeb, :controller

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.Deploy

  def create(conn, %{"description" => description}) do
    attrs = %{
      description: description,
      deployed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case %Deploy{} |> Deploy.changeset(attrs) |> Repo.insert() do
      {:ok, deploy} ->
        conn
        |> put_status(:created)
        |> json(%{id: deploy.id, deployed_at: deploy.deployed_at, description: deploy.description})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def create(conn, _params) do
    attrs = %{
      description: nil,
      deployed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    {:ok, deploy} = %Deploy{} |> Deploy.changeset(attrs) |> Repo.insert()

    conn
    |> put_status(:created)
    |> json(%{id: deploy.id, deployed_at: deploy.deployed_at})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
