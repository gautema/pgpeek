defmodule PgpeekWeb.QueryDetailLiveTest do
  use PgpeekWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.{Snapshot, QueryStat}

  @moduletag :authenticated

  defp create_query_with_history do
    t1 = ~U[2024-01-01 10:00:00Z]
    t2 = ~U[2024-01-01 11:00:00Z]

    s1 = Repo.insert!(%Snapshot{captured_at: t1})
    s2 = Repo.insert!(%Snapshot{captured_at: t2})

    Repo.insert!(%QueryStat{
      snapshot_id: s1.id,
      query_id: "q1",
      query_text: "SELECT * FROM users WHERE id = $1",
      calls: 100,
      mean_exec_time: 2.0,
      total_exec_time: 200.0,
      rows: 100,
      shared_blks_hit: 90,
      shared_blks_read: 10
    })

    Repo.insert!(%QueryStat{
      snapshot_id: s2.id,
      query_id: "q1",
      query_text: "SELECT * FROM users WHERE id = $1",
      calls: 200,
      mean_exec_time: 2.5,
      total_exec_time: 500.0,
      rows: 200,
      shared_blks_hit: 180,
      shared_blks_read: 20
    })

    {s1, s2}
  end

  test "renders query detail page", %{conn: conn} do
    create_query_with_history()

    {:ok, view, _html} = live(conn, "/queries/q1")
    assert has_element?(view, "h1", "Query Detail")
  end

  test "shows the full query text", %{conn: conn} do
    create_query_with_history()

    {:ok, _view, html} = live(conn, "/queries/q1")
    assert html =~ "SELECT * FROM users WHERE id = $1"
  end

  test "shows history entries", %{conn: conn} do
    create_query_with_history()

    {:ok, view, _html} = live(conn, "/queries/q1")
    assert has_element?(view, "h2", "Activity per Period")
  end

  test "shows current stats", %{conn: conn} do
    create_query_with_history()

    {:ok, view, _html} = live(conn, "/queries/q1")
    # Should show mean time, total time, calls, rows
    assert has_element?(view, "p", "Mean Time")
    assert has_element?(view, "p", "Total Time")
    assert has_element?(view, "p", "Calls")
    assert has_element?(view, "p", "Rows")
  end

  test "shows back link to queries", %{conn: conn} do
    create_query_with_history()

    {:ok, view, _html} = live(conn, "/queries/q1")
    assert has_element?(view, "a[href='/queries']")
  end

  test "renders empty state for unknown query", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/queries/unknown")
    assert has_element?(view, "div", "No recent activity detected for this query.")
  end

  test "shows explain plan button when query text exists", %{conn: conn} do
    create_query_with_history()

    {:ok, view, _html} = live(conn, "/queries/q1")
    assert has_element?(view, "button", "Explain Plan")
  end

  test "does not show explain button for unknown query", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/queries/unknown")
    refute has_element?(view, "button", "Explain Plan")
  end
end
