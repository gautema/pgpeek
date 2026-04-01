defmodule PgpeekWeb.SessionController do
  use PgpeekWeb, :controller

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Pgpeek.Auth.authenticate(email, password) do
      {:ok, user} ->
        Pgpeek.Auth.record_login(user)

        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: "/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, error: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
