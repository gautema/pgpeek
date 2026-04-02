defmodule Pgpeek.SystemStats do
  @moduledoc """
  Collects system-level Postgres metrics for time-series tracking.
  Called by SnapshotWorker alongside query stats.
  """

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.SystemStat
  alias Pgpeek.ProbeRepo

  import Ecto.Query

  @doc "Collect all system stats and insert for the given snapshot."
  def capture(snapshot_id) do
    stats =
      %{snapshot_id: snapshot_id}
      |> Map.merge(collect_cache_hit())
      |> Map.merge(collect_connections())
      |> Map.merge(collect_database_stats())
      |> Map.merge(collect_bgwriter())
      |> Map.merge(collect_wal())
      |> Map.merge(collect_replication_lag())
      |> Map.merge(collect_tx_wraparound())
      |> Map.merge(collect_database_size())

    # Coerce Decimals to integers/floats for Ecto
    clean_stats =
      Map.new(stats, fn
        {k, %Decimal{} = v} when k == :cache_hit_ratio -> {k, Decimal.to_float(v)}
        {k, %Decimal{} = v} -> {k, Decimal.to_integer(v)}
        pair -> pair
      end)

    Repo.insert_all(SystemStat, [clean_stats])
    :ok
  end

  @doc "Get system stats trend for charting (newest first)."
  def trend(limit \\ 288) do
    SystemStat
    |> join(:inner, [ss], s in Pgpeek.Schemas.Snapshot, on: ss.snapshot_id == s.id)
    |> order_by([ss, s], desc: s.captured_at)
    |> limit(^limit)
    |> select([ss, s], %{
      captured_at: s.captured_at,
      cache_hit_ratio: ss.cache_hit_ratio,
      total_connections: ss.total_connections,
      active_connections: ss.active_connections,
      idle_in_transaction: ss.idle_in_transaction,
      replication_lag_bytes: ss.replication_lag_bytes,
      temp_bytes: ss.temp_bytes,
      deadlocks: ss.deadlocks,
      wal_bytes: ss.wal_bytes,
      checkpoints_timed: ss.checkpoints_timed,
      checkpoints_requested: ss.checkpoints_requested,
      tx_wraparound_age: ss.tx_wraparound_age,
      database_size_bytes: ss.database_size_bytes
    })
    |> Repo.all()
  end

  defp collect_cache_hit do
    case ProbeRepo.query("""
         SELECT
           CASE sum(blks_hit) + sum(blks_read) WHEN 0 THEN 0
             ELSE round((sum(blks_hit)::numeric / (sum(blks_hit) + sum(blks_read))) * 100, 2)
           END AS ratio
         FROM pg_stat_database
         """) do
      {:ok, %{rows: [[ratio]]}} ->
        %{cache_hit_ratio: decimal_to_float(ratio)}

      _ ->
        %{cache_hit_ratio: nil}
    end
  end

  defp collect_connections do
    case ProbeRepo.query("""
         SELECT
           (SELECT count(*) FROM pg_stat_activity) AS total,
           (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') AS active,
           (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction') AS idle_tx,
           (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_conn
         """) do
      {:ok, %{rows: [[total, active, idle_tx, max_conn]]}} ->
        %{
          total_connections: total,
          active_connections: active,
          idle_in_transaction: idle_tx,
          max_connections: max_conn
        }

      _ ->
        %{
          total_connections: nil,
          active_connections: nil,
          idle_in_transaction: nil,
          max_connections: nil
        }
    end
  end

  defp collect_database_stats do
    case ProbeRepo.query("""
         SELECT temp_bytes, deadlocks
         FROM pg_stat_database
         WHERE datname = current_database()
         """) do
      {:ok, %{rows: [[temp_bytes, deadlocks]]}} ->
        %{temp_bytes: temp_bytes, deadlocks: deadlocks}

      _ ->
        %{temp_bytes: nil, deadlocks: nil}
    end
  end

  defp collect_bgwriter do
    case ProbeRepo.query("""
         SELECT checkpoints_timed, checkpoints_req, buffers_checkpoint
         FROM pg_stat_bgwriter
         """) do
      {:ok, %{rows: [[timed, req, buffers]]}} ->
        %{checkpoints_timed: timed, checkpoints_requested: req, buffers_checkpoint: buffers}

      _ ->
        %{checkpoints_timed: nil, checkpoints_requested: nil, buffers_checkpoint: nil}
    end
  end

  defp collect_wal do
    case ProbeRepo.query("SELECT wal_bytes FROM pg_stat_wal") do
      {:ok, %{rows: [[wal_bytes]]}} ->
        %{wal_bytes: wal_bytes}

      _ ->
        %{wal_bytes: nil}
    end
  end

  defp collect_replication_lag do
    case ProbeRepo.query("""
         SELECT max(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn))::bigint
         FROM pg_stat_replication
         """) do
      {:ok, %{rows: [[lag]]}} ->
        %{replication_lag_bytes: lag}

      _ ->
        %{replication_lag_bytes: nil}
    end
  end

  defp collect_tx_wraparound do
    case ProbeRepo.query("""
         SELECT max(age(datfrozenxid))
         FROM pg_database
         WHERE datname = current_database()
         """) do
      {:ok, %{rows: [[age]]}} ->
        %{tx_wraparound_age: age}

      _ ->
        %{tx_wraparound_age: nil}
    end
  end

  defp collect_database_size do
    case ProbeRepo.query("SELECT pg_database_size(current_database())") do
      {:ok, %{rows: [[size]]}} ->
        %{database_size_bytes: size}

      _ ->
        %{database_size_bytes: nil}
    end
  end

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(f) when is_float(f), do: f
  defp decimal_to_float(i) when is_integer(i), do: i * 1.0
  defp decimal_to_float(_), do: nil
end
