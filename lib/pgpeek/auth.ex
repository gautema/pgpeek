defmodule Pgpeek.Auth do
  @moduledoc "Authentication and user management."

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.User

  import Ecto.Query

  def seed_admin_user! do
    if Repo.aggregate(User, :count) == 0 do
      password = Application.get_env(:pgpeek, :admin_password)

      if password && password != "" do
        %User{}
        |> User.changeset(%{email: "admin@pgpeek.local", password: password})
        |> Repo.insert!()
      end
    end
  end

  def authenticate(email, password) do
    user = Repo.get_by(User, email: email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  def get_user!(id), do: Repo.get!(User, id)

  def record_login(user) do
    user
    |> Ecto.Changeset.change(last_login_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  def change_password(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def list_users do
    User
    |> order_by(asc: :email)
    |> Repo.all()
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def delete_user(user) do
    Repo.delete(user)
  end

  def user_count do
    Repo.aggregate(User, :count)
  end
end
