defmodule PgpeekWeb.AuthHooks do
  @moduledoc "on_mount hooks for LiveView authentication."

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:require_auth, _params, session, socket) do
    user_id = session["user_id"]

    if user_id do
      try do
        user = Pgpeek.Auth.get_user!(user_id)
        {:cont, assign(socket, :current_user, user)}
      rescue
        Ecto.NoResultsError ->
          {:halt, redirect(socket, to: "/login")}
      end
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end
end
