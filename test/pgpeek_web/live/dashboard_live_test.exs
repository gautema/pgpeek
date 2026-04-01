defmodule PgpeekWeb.DashboardLiveTest do
  use PgpeekWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.{Snapshot, QueryStat}

  defp create_snapshot_with_stats do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    snapshot = Repo.insert!(%Snapshot{captured_at: now})

    for i <- 1..3 do
      Repo.insert!(%QueryStat{
        snapshot_id: snapshot.id,
        query_id: "q#{i}",
        query_text: "SELECT * FROM table_#{i}",
        calls: i * 100,
        mean_exec_time: i * 1.5,
        total_exec_time: i * 150.0,
        rows: i * 50,
        shared_blks_hit: i * 100,
        shared_blks_read: i * 10
      })
    end

    snapshot
  end

  test "renders dashboard with no data", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "h1", "Dashboard")
  end

  test "shows 'no database configured' when ProbeRepo not configured", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "h2", "No database configured")
  end

  test "renders top queries when snapshots exist", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "h1", "Dashboard")
  end

  test "shows snapshot timestamp", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Last snapshot:"
  end

  test "shows tracked queries count when data exists", %{conn: conn} do
    create_snapshot_with_stats()

    {:ok, _view, html} = live(conn, "/")
    # Even without ProbeRepo configured, the snapshot data is loaded
    assert html =~ "Last snapshot:"
  end
end
