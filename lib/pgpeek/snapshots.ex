defmodule Pgpeek.Snapshots do
  @moduledoc "Context module for snapshot queries."

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.{Snapshot, QueryStat}

  import Ecto.Query

  def list_snapshots(limit \\ 50) do
    Snapshot
    |> order_by(desc: :captured_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_latest_snapshot do
    Snapshot
    |> order_by(desc: :captured_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_previous_snapshot(snapshot) do
    Snapshot
    |> where([s], s.captured_at < ^snapshot.captured_at)
    |> order_by(desc: :captured_at)
    |> limit(1)
    |> Repo.one()
  end

  def create_snapshot(attrs) do
    %Snapshot{}
    |> Snapshot.changeset(attrs)
    |> Repo.insert()
  end

  def insert_query_stats(snapshot_id, stats_rows) do
    # pg_stat_statements can have multiple rows per queryid
    # (different users, databases, or toplevel flags).
    # Aggregate them into a single row per queryid.
    entries =
      stats_rows
      |> Enum.group_by(fn row -> row["queryid"] end)
      |> Enum.map(fn {_queryid, rows} ->
        first = hd(rows)

        %{
          snapshot_id: snapshot_id,
          query_id: to_string(first["queryid"]),
          query_text: first["query"],
          calls: rows |> Enum.map(& &1["calls"]) |> Enum.sum(),
          total_exec_time: rows |> Enum.map(& &1["total_exec_time"]) |> sum_floats(),
          mean_exec_time: nil,
          min_exec_time: rows |> Enum.map(& &1["min_exec_time"]) |> min_floats(),
          max_exec_time: rows |> Enum.map(& &1["max_exec_time"]) |> max_floats(),
          stddev_exec_time: first["stddev_exec_time"],
          rows: rows |> Enum.map(& &1["rows"]) |> Enum.sum(),
          shared_blks_hit: rows |> Enum.map(& &1["shared_blks_hit"]) |> Enum.sum(),
          shared_blks_read: rows |> Enum.map(& &1["shared_blks_read"]) |> Enum.sum()
        }
      end)
      |> Enum.map(fn entry ->
        # Compute mean from aggregated totals
        mean =
          if entry.calls > 0,
            do: entry.total_exec_time / entry.calls,
            else: 0.0

        %{entry | mean_exec_time: mean}
      end)

    # Insert in batches to avoid SQLite limits
    entries
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      Repo.insert_all(QueryStat, batch)
    end)

    :ok
  end

  defp sum_floats(vals), do: Enum.reduce(vals, 0.0, &((&1 || 0.0) + &2))
  defp min_floats(vals), do: vals |> Enum.reject(&is_nil/1) |> Enum.min(fn -> 0.0 end)
  defp max_floats(vals), do: vals |> Enum.reject(&is_nil/1) |> Enum.max(fn -> 0.0 end)

  def top_queries_by_total_time(snapshot_id, limit \\ 10) do
    QueryStat
    |> where(snapshot_id: ^snapshot_id)
    |> order_by(desc: :total_exec_time)
    |> limit(^limit)
    |> Repo.all()
  end

  def query_stats_for_snapshot(snapshot_id) do
    QueryStat
    |> where(snapshot_id: ^snapshot_id)
    |> Repo.all()
  end

  def query_history(query_id, limit \\ 100) do
    QueryStat
    |> join(:inner, [qs], s in Snapshot, on: qs.snapshot_id == s.id)
    |> where([qs], qs.query_id == ^query_id)
    |> order_by([qs, s], desc: s.captured_at)
    |> limit(^limit)
    |> select([qs, s], %{
      captured_at: s.captured_at,
      calls: qs.calls,
      mean_exec_time: qs.mean_exec_time,
      total_exec_time: qs.total_exec_time,
      rows: qs.rows
    })
    |> Repo.all()
  end

  @doc "Compute deltas between two snapshots for a given query."
  def compute_deltas(current_stats, previous_stats) do
    prev_map = Map.new(previous_stats, &{&1.query_id, &1})

    Enum.map(current_stats, fn stat ->
      case Map.get(prev_map, stat.query_id) do
        nil ->
          # New query, no delta
          %{stat: stat, delta_calls: stat.calls, delta_total_time: stat.total_exec_time, delta_mean_time: stat.mean_exec_time, new: true}

        prev ->
          delta_calls = (stat.calls || 0) - (prev.calls || 0)
          delta_total_time = (stat.total_exec_time || 0) - (prev.total_exec_time || 0)

          delta_mean_time =
            if delta_calls > 0, do: delta_total_time / delta_calls, else: 0.0

          if delta_calls < 0 or delta_total_time < 0 do
            # Stats were reset — skip
            %{stat: stat, delta_calls: 0, delta_total_time: 0, delta_mean_time: 0, reset: true}
          else
            %{stat: stat, delta_calls: delta_calls, delta_total_time: delta_total_time, delta_mean_time: delta_mean_time, new: false}
          end
      end
    end)
    |> Enum.reject(&(&1[:reset] == true))
    |> Enum.sort_by(& &1.delta_total_time, :desc)
  end

  @doc "Detect suspected N+1 queries."
  def detect_n_plus_one(deltas, period_minutes) do
    Enum.filter(deltas, fn d ->
      calls_per_min = if period_minutes > 0, do: d.delta_calls / period_minutes, else: 0
      mean_time = d.stat.mean_exec_time || 0
      query = d.stat.query_text || ""

      calls_per_min > 10 and
        mean_time < 5.0 and
        String.contains?(query, "$1")
    end)
  end

  @doc "Detect regressed queries (mean time > 2x 7-day baseline)."
  def detect_regressions(current_stats) do
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    Enum.filter(current_stats, fn stat ->
      baseline = get_baseline_mean(stat.query_id, seven_days_ago)

      baseline > 0 and
        (stat.mean_exec_time || 0) > baseline * 2 and
        (stat.calls || 0) >= 100
    end)
  end

  defp get_baseline_mean(query_id, since) do
    result =
      QueryStat
      |> join(:inner, [qs], s in Snapshot, on: qs.snapshot_id == s.id)
      |> where([qs, s], qs.query_id == ^query_id and s.captured_at >= ^since)
      |> select([qs], avg(qs.mean_exec_time))
      |> Repo.one()

    result || 0.0
  end
end
