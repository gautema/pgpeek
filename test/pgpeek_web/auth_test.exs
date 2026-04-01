defmodule PgpeekWeb.AuthTest do
  use PgpeekWeb.ConnCase

  describe "unauthenticated access" do
    test "redirects to login for protected routes", %{conn: conn} do
      conn = get(conn, "/")
      assert redirected_to(conn) == "/login"
    end

    test "redirects to login for /queries", %{conn: conn} do
      conn = get(conn, "/queries")
      assert redirected_to(conn) == "/login"
    end

    test "redirects to login for /diagnose", %{conn: conn} do
      conn = get(conn, "/diagnose")
      assert redirected_to(conn) == "/login"
    end

    test "redirects to login for /settings", %{conn: conn} do
      conn = get(conn, "/settings")
      assert redirected_to(conn) == "/login"
    end

    test "allows access to /login", %{conn: conn} do
      conn = get(conn, "/login")
      assert html_response(conn, 200) =~ "Sign in"
    end

    test "allows access to /api/deploys", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/deploys", %{description: "test"})

      assert json_response(conn, 201)
    end
  end
end
