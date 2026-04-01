defmodule PgpeekWeb.QueriesLiveTest do
  use PgpeekWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.{Snapshot, QueryStat}

  @moduletag :authenticated

  defp create_snapshot_with_stats do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    snapshot = Repo.insert!(%Snapshot{captured_at: now})

    Repo.insert!(%QueryStat{
      snapshot_id: snapshot.id,
      query_id: "q1",
      query_text: "SELECT * FROM users WHERE id = $1",
      calls: 1000,
      mean_exec_time: 2.5,
      total_exec_time: 2500.0,
      rows: 1000,
      shared_blks_hit: 900,
      shared_blks_read: 100
    })

    Repo.insert!(%QueryStat{
      snapshot_id: snapshot.id,
      query_id: "q2",
      query_text: "SELECT count(*) FROM orders",
      calls: 50,
      mean_exec_time: 150.0,
      total_exec_time: 7500.0,
      rows: 50,
      shared_blks_hit: 200,
      shared_blks_read: 50
    })

    snapshot
  end

  test "renders queries page with no data", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/queries")
    assert has_element?(view, "h1", "Queries")
    assert has_element?(view, "div", "No query data yet")
  end

  test "renders query list when data exists", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, view, _html} = live(conn, "/queries")
    assert has_element?(view, "h1", "Queries")
  end

  test "sorting by different columns", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, view, _html} = live(conn, "/queries")

    # Click to sort by calls
    html = view |> element("th", "Calls") |> render_click()
    assert html =~ "SELECT"

    # Click again to reverse sort
    html = view |> element("th", "Calls") |> render_click()
    assert html =~ "SELECT"
  end

  test "sorting by mean time", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, view, _html} = live(conn, "/queries")
    html = view |> element("th", "Mean Time") |> render_click()
    assert html =~ "SELECT"
  end

  test "query links point to detail pages", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, view, _html} = live(conn, "/queries")
    assert has_element?(view, "a[href='/queries/q1']")
    assert has_element?(view, "a[href='/queries/q2']")
  end
end
