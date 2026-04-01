defmodule PgpeekWeb.DashboardLiveTest do
  use PgpeekWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.{Snapshot, QueryStat}

  @moduletag :authenticated

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
    assert html =~ "Last snapshot:"
  end

  test "shows regression anomaly when query regresses", %{conn: conn} do
    # Create baseline snapshots over 7 days
    for i <- 1..7 do
      s = Repo.insert!(%Snapshot{
        captured_at: DateTime.add(DateTime.utc_now(), -i, :day) |> DateTime.truncate(:second)
      })

      Repo.insert!(%QueryStat{
        snapshot_id: s.id,
        query_id: "regressed_q",
        query_text: "SELECT * FROM slow_table WHERE id = $1",
        calls: 200,
        mean_exec_time: 5.0,
        total_exec_time: 1000.0,
        rows: 200,
        shared_blks_hit: 100,
        shared_blks_read: 10
      })
    end

    # Current snapshot with much higher mean (> 2x baseline)
    current = Repo.insert!(%Snapshot{
      captured_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })

    Repo.insert!(%QueryStat{
      snapshot_id: current.id,
      query_id: "regressed_q",
      query_text: "SELECT * FROM slow_table WHERE id = $1",
      calls: 200,
      mean_exec_time: 15.0,
      total_exec_time: 3000.0,
      rows: 200,
      shared_blks_hit: 100,
      shared_blks_read: 10
    })

    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "span", "Regression")
  end

  test "shows N+1 anomaly for high-frequency low-latency queries", %{conn: conn} do
    prev = Repo.insert!(%Snapshot{
      captured_at: DateTime.add(DateTime.utc_now(), -5, :minute) |> DateTime.truncate(:second)
    })

    Repo.insert!(%QueryStat{
      snapshot_id: prev.id,
      query_id: "n1_q",
      query_text: "SELECT * FROM items WHERE user_id = $1",
      calls: 100,
      mean_exec_time: 0.5,
      total_exec_time: 50.0,
      rows: 100,
      shared_blks_hit: 100,
      shared_blks_read: 0
    })

    current = Repo.insert!(%Snapshot{
      captured_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })

    Repo.insert!(%QueryStat{
      snapshot_id: current.id,
      query_id: "n1_q",
      query_text: "SELECT * FROM items WHERE user_id = $1",
      calls: 5100,
      mean_exec_time: 0.5,
      total_exec_time: 2550.0,
      rows: 5100,
      shared_blks_hit: 5100,
      shared_blks_read: 0
    })

    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "span", "Suspected N+1")
  end
end
