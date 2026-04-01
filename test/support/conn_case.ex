defmodule PgpeekWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PgpeekWeb.Endpoint

      use PgpeekWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import PgpeekWeb.ConnCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Pgpeek.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    conn = Phoenix.ConnTest.build_conn()

    if tags[:authenticated] do
      user = create_test_user()
      conn = log_in_user(conn, user)
      {:ok, conn: conn, user: user}
    else
      {:ok, conn: conn}
    end
  end

  @doc "Create a test user for authentication."
  def create_test_user(attrs \\ %{}) do
    default = %{email: "test@pgpeek.local", password: "testpassword123"}

    %Pgpeek.Schemas.User{}
    |> Pgpeek.Schemas.User.changeset(Map.merge(default, attrs))
    |> Pgpeek.Repo.insert!()
  end

  @doc "Log in a user by putting their ID in the session."
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
