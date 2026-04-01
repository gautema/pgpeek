defmodule Pgpeek.SnapshotsTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Snapshots
  alias Pgpeek.Schemas.QueryStat

  defp create_snapshot(attrs \\ %{}) do
    default = %{captured_at: DateTime.utc_now() |> DateTime.truncate(:second)}

    {:ok, snapshot} = Snapshots.create_snapshot(Map.merge(default, attrs))
    snapshot
  end

  defp insert_stats(snapshot_id, stats) do
    Enum.each(stats, fn stat ->
      %QueryStat{}
      |> QueryStat.changeset(Map.put(stat, :snapshot_id, snapshot_id))
      |> Repo.insert!()
    end)
  end

  describe "create_snapshot/1" do
    test "creates a snapshot with captured_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, snapshot} = Snapshots.create_snapshot(%{captured_at: now})

      assert snapshot.id
      assert snapshot.captured_at == now
    end

    test "creates a snapshot with stats_reset_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, snapshot} =
        Snapshots.create_snapshot(%{captured_at: now, stats_reset_at: now})

      assert snapshot.stats_reset_at == now
    end
  end

  describe "get_latest_snapshot/0" do
    test "returns the most recent snapshot" do
      t1 = ~U[2024-01-01 10:00:00Z]
      t2 = ~U[2024-01-01 11:00:00Z]
      _old = create_snapshot(%{captured_at: t1})
      latest = create_snapshot(%{captured_at: t2})

      assert Snapshots.get_latest_snapshot().id == latest.id
    end

    test "returns nil when no snapshots exist" do
      assert Snapshots.get_latest_snapshot() == nil
    end
  end

  describe "get_previous_snapshot/1" do
    test "returns the snapshot before the given one" do
      t1 = ~U[2024-01-01 10:00:00Z]
      t2 = ~U[2024-01-01 11:00:00Z]
      t3 = ~U[2024-01-01 12:00:00Z]
      first = create_snapshot(%{captured_at: t1})
      second = create_snapshot(%{captured_at: t2})
      third = create_snapshot(%{captured_at: t3})

      assert Snapshots.get_previous_snapshot(third).id == second.id
      assert Snapshots.get_previous_snapshot(second).id == first.id
    end

    test "returns nil for the first snapshot" do
      snapshot = create_snapshot(%{captured_at: ~U[2024-01-01 10:00:00Z]})
      assert Snapshots.get_previous_snapshot(snapshot) == nil
    end
  end

  describe "list_snapshots/1" do
    test "returns snapshots ordered by captured_at desc" do
      t1 = ~U[2024-01-01 10:00:00Z]
      t2 = ~U[2024-01-01 11:00:00Z]
      t3 = ~U[2024-01-01 12:00:00Z]
      create_snapshot(%{captured_at: t1})
      create_snapshot(%{captured_at: t2})
      create_snapshot(%{captured_at: t3})

      snapshots = Snapshots.list_snapshots()
      assert length(snapshots) == 3
      assert hd(snapshots).captured_at == t3
    end

    test "respects the limit" do
      for i <- 1..5 do
        create_snapshot(%{captured_at: DateTime.add(~U[2024-01-01 10:00:00Z], i, :hour)})
      end

      assert length(Snapshots.list_snapshots(3)) == 3
    end
  end

  describe "insert_query_stats/2" do
    test "inserts query stats rows for a snapshot" do
      snapshot = create_snapshot()

      rows = [
        %{
          "queryid" => 123,
          "query" => "SELECT 1",
          "calls" => 100,
          "mean_exec_time" => 1.5,
          "total_exec_time" => 150.0,
          "min_exec_time" => 0.5,
          "max_exec_time" => 5.0,
          "stddev_exec_time" => 0.8,
          "rows" => 100,
          "shared_blks_hit" => 50,
          "shared_blks_read" => 5
        },
        %{
          "queryid" => 456,
          "query" => "SELECT * FROM users",
          "calls" => 50,
          "mean_exec_time" => 3.0,
          "total_exec_time" => 150.0,
          "min_exec_time" => 1.0,
          "max_exec_time" => 10.0,
          "stddev_exec_time" => 2.0,
          "rows" => 500,
          "shared_blks_hit" => 200,
          "shared_blks_read" => 20
        }
      ]

      assert :ok = Snapshots.insert_query_stats(snapshot.id, rows)

      stats = Repo.all(from(qs in QueryStat, where: qs.snapshot_id == ^snapshot.id))
      assert length(stats) == 2
    end

    test "handles empty rows" do
      snapshot = create_snapshot()
      assert :ok = Snapshots.insert_query_stats(snapshot.id, [])
    end

    test "aggregates duplicate queryids into a single row" do
      snapshot = create_snapshot()

      rows = [
        %{
          "queryid" => 123,
          "query" => "SELECT 1",
          "calls" => 100,
          "mean_exec_time" => 1.0,
          "total_exec_time" => 100.0,
          "min_exec_time" => 0.5,
          "max_exec_time" => 5.0,
          "stddev_exec_time" => 0.8,
          "rows" => 100,
          "shared_blks_hit" => 50,
          "shared_blks_read" => 5
        },
        %{
          "queryid" => 123,
          "query" => "SELECT 1",
          "calls" => 200,
          "mean_exec_time" => 2.0,
          "total_exec_time" => 400.0,
          "min_exec_time" => 0.3,
          "max_exec_time" => 8.0,
          "stddev_exec_time" => 1.0,
          "rows" => 200,
          "shared_blks_hit" => 80,
          "shared_blks_read" => 10
        },
        %{
          "queryid" => 123,
          "query" => "SELECT 1",
          "calls" => 50,
          "mean_exec_time" => 0.5,
          "total_exec_time" => 25.0,
          "min_exec_time" => 0.1,
          "max_exec_time" => 3.0,
          "stddev_exec_time" => 0.5,
          "rows" => 50,
          "shared_blks_hit" => 20,
          "shared_blks_read" => 2
        }
      ]

      assert :ok = Snapshots.insert_query_stats(snapshot.id, rows)

      stats = Repo.all(from(qs in QueryStat, where: qs.snapshot_id == ^snapshot.id))
      assert length(stats) == 1

      stat = hd(stats)
      assert stat.calls == 350
      assert stat.total_exec_time == 525.0
      assert stat.rows == 350
      assert stat.shared_blks_hit == 150
      assert stat.shared_blks_read == 17
      assert stat.min_exec_time == 0.1
      assert stat.max_exec_time == 8.0
      # mean should be total / calls
      assert_in_delta stat.mean_exec_time, 525.0 / 350, 0.001
    end
  end

  describe "top_queries_by_total_time/2" do
    test "returns top queries ordered by total_exec_time desc" do
      snapshot = create_snapshot()

      insert_stats(snapshot.id, [
        %{query_id: "1", query_text: "SELECT 1", total_exec_time: 100.0, calls: 10},
        %{query_id: "2", query_text: "SELECT 2", total_exec_time: 500.0, calls: 20},
        %{query_id: "3", query_text: "SELECT 3", total_exec_time: 200.0, calls: 15}
      ])

      top = Snapshots.top_queries_by_total_time(snapshot.id, 2)
      assert length(top) == 2
      assert hd(top).query_id == "2"
    end
  end

  describe "query_stats_for_snapshot/1" do
    test "returns all stats for a snapshot" do
      snapshot = create_snapshot()

      insert_stats(snapshot.id, [
        %{query_id: "1", calls: 10},
        %{query_id: "2", calls: 20}
      ])

      stats = Snapshots.query_stats_for_snapshot(snapshot.id)
      assert length(stats) == 2
    end
  end

  describe "query_history/2" do
    test "returns history for a specific query across snapshots" do
      s1 = create_snapshot(%{captured_at: ~U[2024-01-01 10:00:00Z]})
      s2 = create_snapshot(%{captured_at: ~U[2024-01-01 11:00:00Z]})

      insert_stats(s1.id, [
        %{query_id: "q1", calls: 10, mean_exec_time: 1.0, total_exec_time: 10.0, rows: 10}
      ])

      insert_stats(s2.id, [
        %{query_id: "q1", calls: 20, mean_exec_time: 1.5, total_exec_time: 30.0, rows: 20}
      ])

      history = Snapshots.query_history("q1")
      assert length(history) == 2
      # Most recent first
      assert hd(history).calls == 20
    end

    test "returns empty list for unknown query" do
      assert Snapshots.query_history("nonexistent") == []
    end
  end

  describe "compute_deltas/2" do
    test "computes correct deltas between snapshots" do
      current = [
        %QueryStat{query_id: "1", calls: 150, total_exec_time: 300.0, mean_exec_time: 2.0},
        %QueryStat{query_id: "2", calls: 200, total_exec_time: 600.0, mean_exec_time: 3.0}
      ]

      previous = [
        %QueryStat{query_id: "1", calls: 100, total_exec_time: 200.0, mean_exec_time: 2.0},
        %QueryStat{query_id: "2", calls: 150, total_exec_time: 450.0, mean_exec_time: 3.0}
      ]

      deltas = Snapshots.compute_deltas(current, previous)
      assert length(deltas) == 2

      delta_1 = Enum.find(deltas, &(&1.stat.query_id == "1"))
      assert delta_1.delta_calls == 50
      assert delta_1.delta_total_time == 100.0
      assert delta_1.delta_mean_time == 2.0
    end

    test "marks new queries appropriately" do
      current = [
        %QueryStat{query_id: "new", calls: 10, total_exec_time: 50.0, mean_exec_time: 5.0}
      ]

      deltas = Snapshots.compute_deltas(current, [])
      assert length(deltas) == 1
      assert hd(deltas).new == true
      assert hd(deltas).delta_calls == 10
    end

    test "skips queries with negative deltas (stats reset)" do
      current = [
        %QueryStat{query_id: "1", calls: 10, total_exec_time: 20.0, mean_exec_time: 2.0}
      ]

      previous = [
        %QueryStat{query_id: "1", calls: 100, total_exec_time: 200.0, mean_exec_time: 2.0}
      ]

      deltas = Snapshots.compute_deltas(current, previous)
      assert deltas == []
    end

    test "handles zero delta calls" do
      current = [
        %QueryStat{query_id: "1", calls: 100, total_exec_time: 200.0, mean_exec_time: 2.0}
      ]

      previous = [
        %QueryStat{query_id: "1", calls: 100, total_exec_time: 200.0, mean_exec_time: 2.0}
      ]

      deltas = Snapshots.compute_deltas(current, previous)
      assert length(deltas) == 1
      assert hd(deltas).delta_calls == 0
      assert hd(deltas).delta_mean_time == 0.0
    end

    test "sorts results by delta_total_time descending" do
      current = [
        %QueryStat{query_id: "1", calls: 110, total_exec_time: 220.0, mean_exec_time: 2.0},
        %QueryStat{query_id: "2", calls: 120, total_exec_time: 500.0, mean_exec_time: 4.0}
      ]

      previous = [
        %QueryStat{query_id: "1", calls: 100, total_exec_time: 200.0, mean_exec_time: 2.0},
        %QueryStat{query_id: "2", calls: 100, total_exec_time: 200.0, mean_exec_time: 2.0}
      ]

      deltas = Snapshots.compute_deltas(current, previous)
      assert hd(deltas).stat.query_id == "2"
    end
  end

  describe "detect_n_plus_one/2" do
    test "flags high frequency, low latency queries with parameter pattern" do
      deltas = [
        %{
          stat: %QueryStat{
            query_id: "1",
            mean_exec_time: 0.5,
            query_text: "SELECT * FROM users WHERE id = $1"
          },
          delta_calls: 500,
          delta_total_time: 250.0,
          delta_mean_time: 0.5
        },
        %{
          stat: %QueryStat{
            query_id: "2",
            mean_exec_time: 50.0,
            query_text: "SELECT * FROM reports"
          },
          delta_calls: 5,
          delta_total_time: 250.0,
          delta_mean_time: 50.0
        }
      ]

      suspects = Snapshots.detect_n_plus_one(deltas, 5)
      assert length(suspects) == 1
      assert hd(suspects).stat.query_id == "1"
    end

    test "does not flag queries with high mean time" do
      deltas = [
        %{
          stat: %QueryStat{
            query_id: "1",
            mean_exec_time: 10.0,
            query_text: "SELECT * FROM users WHERE id = $1"
          },
          delta_calls: 500,
          delta_total_time: 5000.0,
          delta_mean_time: 10.0
        }
      ]

      assert Snapshots.detect_n_plus_one(deltas, 5) == []
    end

    test "does not flag queries without parameter pattern" do
      deltas = [
        %{
          stat: %QueryStat{
            query_id: "1",
            mean_exec_time: 0.5,
            query_text: "SELECT count(*) FROM users"
          },
          delta_calls: 500,
          delta_total_time: 250.0,
          delta_mean_time: 0.5
        }
      ]

      assert Snapshots.detect_n_plus_one(deltas, 5) == []
    end

    test "handles zero period minutes" do
      deltas = [
        %{
          stat: %QueryStat{
            query_id: "1",
            mean_exec_time: 0.5,
            query_text: "SELECT * FROM users WHERE id = $1"
          },
          delta_calls: 500,
          delta_total_time: 250.0,
          delta_mean_time: 0.5
        }
      ]

      assert Snapshots.detect_n_plus_one(deltas, 0) == []
    end
  end

  describe "detect_regressions/1" do
    test "flags queries exceeding 2x baseline mean with sufficient calls" do
      # Create historical baseline data
      for i <- 1..7 do
        s =
          create_snapshot(%{
            captured_at: DateTime.add(DateTime.utc_now(), -i, :day) |> DateTime.truncate(:second)
          })

        insert_stats(s.id, [%{query_id: "q1", mean_exec_time: 10.0, calls: 200}])
      end

      # Current stat with much higher mean
      current_stats = [
        %QueryStat{query_id: "q1", mean_exec_time: 25.0, calls: 200}
      ]

      regressions = Snapshots.detect_regressions(current_stats)
      assert length(regressions) == 1
    end

    test "does not flag queries with fewer than 100 calls" do
      for i <- 1..7 do
        s =
          create_snapshot(%{
            captured_at: DateTime.add(DateTime.utc_now(), -i, :day) |> DateTime.truncate(:second)
          })

        insert_stats(s.id, [%{query_id: "q1", mean_exec_time: 10.0, calls: 200}])
      end

      current_stats = [
        %QueryStat{query_id: "q1", mean_exec_time: 25.0, calls: 50}
      ]

      assert Snapshots.detect_regressions(current_stats) == []
    end

    test "does not flag queries within normal range" do
      for i <- 1..7 do
        s =
          create_snapshot(%{
            captured_at: DateTime.add(DateTime.utc_now(), -i, :day) |> DateTime.truncate(:second)
          })

        insert_stats(s.id, [%{query_id: "q1", mean_exec_time: 10.0, calls: 200}])
      end

      current_stats = [
        %QueryStat{query_id: "q1", mean_exec_time: 15.0, calls: 200}
      ]

      assert Snapshots.detect_regressions(current_stats) == []
    end
  end

  describe "cleanup_old_snapshots/1" do
    test "deletes snapshots older than retention period" do
      old =
        create_snapshot(%{
          captured_at: DateTime.add(DateTime.utc_now(), -10, :day) |> DateTime.truncate(:second)
        })

      recent = create_snapshot(%{captured_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      deleted = Snapshots.cleanup_old_snapshots(7)
      assert deleted == 1

      assert Repo.get(Pgpeek.Schemas.Snapshot, recent.id)
      refute Repo.get(Pgpeek.Schemas.Snapshot, old.id)
    end

    test "returns 0 when nothing to delete" do
      create_snapshot(%{captured_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      assert Snapshots.cleanup_old_snapshots(7) == 0
    end
  end

  describe "get_query_text/1" do
    test "returns text from query_texts table" do
      Repo.insert!(%Pgpeek.Schemas.QueryText{
        query_id: "qt1",
        query_text: "SELECT * FROM users",
        first_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert Snapshots.get_query_text("qt1") == "SELECT * FROM users"
    end

    test "falls back to query_stats for older data" do
      snapshot = create_snapshot()
      insert_stats(snapshot.id, [%{query_id: "qs1", query_text: "SELECT 1"}])

      assert Snapshots.get_query_text("qs1") == "SELECT 1"
    end

    test "returns nil for unknown query" do
      assert Snapshots.get_query_text("nonexistent") == nil
    end
  end

  describe "insert_query_stats/2 stores query texts separately" do
    test "upserts into query_texts table" do
      snapshot = create_snapshot()

      rows = [
        %{
          "queryid" => 999,
          "query" => "SELECT * FROM orders",
          "calls" => 10,
          "mean_exec_time" => 1.0,
          "total_exec_time" => 10.0,
          "min_exec_time" => 0.5,
          "max_exec_time" => 2.0,
          "stddev_exec_time" => 0.3,
          "rows" => 10,
          "shared_blks_hit" => 5,
          "shared_blks_read" => 1
        }
      ]

      Snapshots.insert_query_stats(snapshot.id, rows)

      qt = Repo.get_by(Pgpeek.Schemas.QueryText, query_id: "999")
      assert qt
      assert qt.query_text == "SELECT * FROM orders"
    end
  end
end
