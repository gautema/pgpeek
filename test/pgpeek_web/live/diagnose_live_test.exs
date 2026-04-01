defmodule PgpeekWeb.DiagnoseLiveTest do
  use PgpeekWeb.ConnCase

  import Phoenix.LiveViewTest

  @moduletag :authenticated

  test "renders diagnose page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/diagnose")
    assert has_element?(view, "h1", "Diagnose")
  end

  test "shows 'no database configured' when ProbeRepo not configured", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/diagnose")
    assert has_element?(view, "h2", "No database configured")
  end

  test "shows subtitle text", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/diagnose")
    assert html =~ "Run diagnostic checks"
  end
end
