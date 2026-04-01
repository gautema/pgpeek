defmodule Pgpeek.Snapshots do
  @moduledoc "Context module for snapshot queries."

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.{Snapshot, QueryStat, QueryText}

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
    now = DateTime.utc_now() |> DateTime.truncate(:second)

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
        mean =
          if entry.calls > 0,
            do: entry.total_exec_time / entry.calls,
            else: 0.0

        %{entry | mean_exec_time: mean}
      end)

    # Upsert query texts (stored once, not per snapshot)
    entries
    |> Enum.filter(& &1.query_text)
    |> Enum.uniq_by(& &1.query_id)
    |> Enum.chunk_every(50)
    |> Enum.each(fn batch ->
      Repo.insert_all(
        QueryText,
        Enum.map(batch, fn e ->
          %{query_id: e.query_id, query_text: e.query_text, first_seen_at: now}
        end),
        on_conflict: {:replace, [:query_text]},
        conflict_target: :query_id
      )
    end)

    # Insert stats WITHOUT query_text (it's in the query_texts table now)
    entries
    |> Enum.map(&Map.delete(&1, :query_text))
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      Repo.insert_all(QueryStat, batch)
    end)

    :ok
  end

  @doc "Get query text from the deduplicated query_texts table, falling back to query_stats."
  def get_query_text(query_id) do
    case Repo.get_by(QueryText, query_id: query_id) do
      %QueryText{query_text: text} when not is_nil(text) ->
        text

      _ ->
        # Fallback: check query_stats for older data that still has query_text
        QueryStat
        |> where(query_id: ^query_id)
        |> where([qs], not is_nil(qs.query_text))
        |> select([qs], qs.query_text)
        |> limit(1)
        |> Repo.one()
    end
  end

  @doc "Enrich query stats with their query text from the query_texts table."
  def with_query_text(stats) when is_list(stats) do
    query_ids = Enum.map(stats, & &1.query_id) |> Enum.uniq()

    texts =
      QueryText
      |> where([qt], qt.query_id in ^query_ids)
      |> select([qt], {qt.query_id, qt.query_text})
      |> Repo.all()
      |> Map.new()

    Enum.map(stats, fn stat ->
      text = Map.get(texts, stat.query_id) || stat.query_text
      %{stat | query_text: text}
    end)
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
    |> with_query_text()
  end

  def query_stats_for_snapshot(snapshot_id) do
    QueryStat
    |> where(snapshot_id: ^snapshot_id)
    |> Repo.all()
    |> with_query_text()
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
          %{
            stat: stat,
            delta_calls: stat.calls,
            delta_total_time: stat.total_exec_time,
            delta_mean_time: stat.mean_exec_time,
            new: true
          }

        prev ->
          delta_calls = (stat.calls || 0) - (prev.calls || 0)
          delta_total_time = (stat.total_exec_time || 0) - (prev.total_exec_time || 0)

          delta_mean_time =
            if delta_calls > 0, do: delta_total_time / delta_calls, else: 0.0

          if delta_calls < 0 or delta_total_time < 0 do
            # Stats were reset — skip
            %{stat: stat, delta_calls: 0, delta_total_time: 0, delta_mean_time: 0, reset: true}
          else
            %{
              stat: stat,
              delta_calls: delta_calls,
              delta_total_time: delta_total_time,
              delta_mean_time: delta_mean_time,
              new: false
            }
          end
      end
    end)
    |> Enum.reject(&(&1[:reset] == true))
    |> Enum.sort_by(& &1.delta_total_time, :desc)
  end

  @doc "Detect suspected N+1 queries."
  def detect_n_plus_one(deltas, period_minutes) do
    deltas
    |> Enum.reject(fn d -> utility_query?(d.stat) end)
    |> Enum.filter(fn d ->
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

    current_stats
    |> Enum.reject(&utility_query?/1)
    |> Enum.filter(fn stat ->
      mean = stat.mean_exec_time || 0
      baseline = get_baseline_mean(stat.query_id, seven_days_ago)

      baseline > 0.1 and
        mean > 0.1 and
        mean > baseline * 2 and
        (stat.calls || 0) >= 100
    end)
  end

  # Filter out transaction control and utility statements that aren't meaningful to track
  defp utility_query?(stat) do
    query = String.upcase(String.trim(stat.query_text || ""))

    Enum.any?(
      ["BEGIN", "COMMIT", "ROLLBACK", "SET ", "RESET ", "DEALLOCATE", "DISCARD"],
      &String.starts_with?(query, &1)
    )
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

  @doc """
  Delete snapshots (and their query_stats via cascade) older than the
  given number of days. Returns the number of deleted snapshots.
  """
  def cleanup_old_snapshots(retention_days \\ 7) do
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days, :day)

    {count, _} =
      Snapshot
      |> where([s], s.captured_at < ^cutoff)
      |> Repo.delete_all()

    count
  end
end
