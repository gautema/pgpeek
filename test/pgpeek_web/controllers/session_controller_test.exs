defmodule PgpeekWeb.SessionControllerTest do
  use PgpeekWeb.ConnCase

  describe "GET /login" do
    test "renders login form", %{conn: conn} do
      conn = get(conn, "/login")
      assert html_response(conn, 200) =~ "Sign in"
    end

    @tag :authenticated
    test "redirects to home when already logged in", %{conn: conn} do
      conn = get(conn, "/login")
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /login" do
    test "logs in with valid credentials", %{conn: conn} do
      create_test_user(%{email: "admin@test.com", password: "password123"})

      conn =
        conn
        |> init_test_session(%{})
        |> post("/login", %{email: "admin@test.com", password: "password123"})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_id)
    end

    test "rejects invalid password", %{conn: conn} do
      create_test_user(%{email: "admin@test.com", password: "password123"})

      conn =
        conn
        |> init_test_session(%{})
        |> post("/login", %{email: "admin@test.com", password: "wrongpassword"})

      assert html_response(conn, 200) =~ "Invalid email or password"
    end

    test "rejects unknown email", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> post("/login", %{email: "nobody@test.com", password: "password123"})

      assert html_response(conn, 200) =~ "Invalid email or password"
    end
  end

  describe "DELETE /logout" do
    @tag :authenticated
    test "logs out the user", %{conn: conn} do
      conn = delete(conn, "/logout")
      assert redirected_to(conn) == "/login"
    end
  end
end
