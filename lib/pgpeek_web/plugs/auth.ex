defmodule PgpeekWeb.Plugs.Auth do
  @moduledoc "Plug that loads the current user from session and protects routes."

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      try do
        user = Pgpeek.Auth.get_user!(user_id)
        assign(conn, :current_user, user)
      rescue
        Ecto.NoResultsError ->
          conn
          |> clear_session()
          |> assign(:current_user, nil)
      end
    else
      assign(conn, :current_user, nil)
    end
  end

  def require_auth(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: "/")
      |> halt()
    else
      conn
    end
  end
end
