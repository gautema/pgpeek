defmodule PgpeekWeb.SettingsLiveTest do
  use PgpeekWeb.ConnCase

  import Phoenix.LiveViewTest

  @moduletag :authenticated

  test "renders settings page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")
    assert has_element?(view, "h1", "Settings")
  end

  test "shows change password form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")
    assert has_element?(view, "#password-form")
  end

  test "shows users table", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")
    assert has_element?(view, "h2", "Users")
  end

  test "shows current user with 'you' badge", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/settings")
    assert html =~ "you"
  end

  test "shows add user form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")
    assert has_element?(view, "#new-user-form")
  end

  test "can change password", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form("#password-form", %{password: %{password: "newpassword123", password_confirmation: "newpassword123"}})
    |> render_submit()

    assert has_element?(view, "div", "Password updated successfully")
  end

  test "shows error when passwords don't match", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form("#password-form", %{password: %{password: "newpassword123", password_confirmation: "different"}})
    |> render_submit()

    assert has_element?(view, "div", "Passwords do not match")
  end

  test "can create a new user", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form("#new-user-form", %{user: %{email: "newuser@test.com", password: "password123"}})
    |> render_submit()

    assert has_element?(view, "div", "User created")
    assert has_element?(view, "td", "newuser@test.com")
  end

  test "cannot delete own account", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, "/settings")

    # The delete button should not appear for the current user
    refute has_element?(view, "button[phx-value-id='#{user.id}']")
  end
end
