defmodule Pgpeek.Settings do
  @moduledoc "Key-value settings stored in SQLite."

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.Setting

  import Ecto.Query

  def get(key, default \\ nil) do
    case Repo.get_by(Setting, key: key) do
      %Setting{value: value} -> value
      nil -> default
    end
  end

  def put(key, value) do
    case Repo.get_by(Setting, key: key) do
      nil ->
        %Setting{}
        |> Setting.changeset(%{key: key, value: value})
        |> Repo.insert()

      existing ->
        existing
        |> Setting.changeset(%{value: value})
        |> Repo.update()
    end
  end

  def delete(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> :ok
      setting -> Repo.delete(setting)
    end
  end

  def all do
    Setting
    |> order_by(:key)
    |> Repo.all()
    |> Map.new(&{&1.key, &1.value})
  end
end
