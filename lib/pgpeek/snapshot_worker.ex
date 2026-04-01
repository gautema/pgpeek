defmodule Pgpeek.SnapshotWorker do
  @moduledoc """
  GenServer that periodically polls pg_stat_statements and stores
  snapshots in SQLite. Broadcasts updates via PubSub.
  """

  use GenServer

  require Logger

  @default_interval 300_000  # 5 minutes

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trigger_snapshot do
    GenServer.cast(__MODULE__, :take_snapshot)
  end

  @impl true
  def init(_opts) do
    interval = Application.get_env(:pgpeek, :snapshot_interval, @default_interval)

    state = %{
      interval: interval,
      last_stats_reset: nil
    }

    # Schedule first snapshot shortly after boot
    if Pgpeek.ProbeRepo.configured?() do
      Process.send_after(self(), :take_snapshot, 5_000)
    else
      Logger.warning("PgPeek: No DATABASE_URL configured — snapshot worker idle")
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:take_snapshot, state) do
    state = do_snapshot(state)
    Process.send_after(self(), :take_snapshot, state.interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:take_snapshot, state) do
    state = do_snapshot(state)
    {:noreply, state}
  end

  defp do_snapshot(state) do
    unless Pgpeek.ProbeRepo.configured?() do
      Logger.warning("PgPeek: No DATABASE_URL configured — skipping snapshot")
      state
    else
      do_snapshot_impl(state)
    end
  end

  defp do_snapshot_impl(state) do
    Logger.info("PgPeek: Taking snapshot...")

    with {:ok, stats_result} <- query_pg_stat_statements(),
         {:ok, reset_result} <- query_stats_reset() do
      stats_reset_at = parse_stats_reset(reset_result)
      reset_changed = state.last_stats_reset != nil and stats_reset_at != state.last_stats_reset

      if reset_changed do
        Logger.warning("PgPeek: pg_stat_statements was reset — skipping delta calculation this cycle")
      end

      captured_at = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, snapshot} =
        Pgpeek.Snapshots.create_snapshot(%{
          captured_at: captured_at,
          stats_reset_at: stats_reset_at
        })

      rows = columns_to_maps(stats_result)
      Pgpeek.Snapshots.insert_query_stats(snapshot.id, rows)

      # Compute deltas and broadcast
      unless reset_changed do
        broadcast_snapshot(snapshot)
      end

      Logger.info("PgPeek: Snapshot #{snapshot.id} captured (#{length(rows)} queries)")

      # Retention cleanup — default 7 days
      retention_days = Application.get_env(:pgpeek, :retention_days, 7)
      deleted = Pgpeek.Snapshots.cleanup_old_snapshots(retention_days)

      if deleted > 0 do
        Logger.info("PgPeek: Cleaned up #{deleted} old snapshots (retention: #{retention_days} days)")
      end

      %{state | last_stats_reset: stats_reset_at}
    else
      {:error, error} ->
        Logger.error("PgPeek: Snapshot failed: #{inspect(error)}")
        state
    end
  end

  defp query_pg_stat_statements do
    Pgpeek.ProbeRepo.query("""
    SELECT queryid, query, calls, mean_exec_time, total_exec_time,
           min_exec_time, max_exec_time, stddev_exec_time, rows,
           shared_blks_hit, shared_blks_read
    FROM pg_stat_statements
    WHERE query NOT LIKE '%pg_stat_statements%'
    ORDER BY total_exec_time DESC
    """)
  end

  defp query_stats_reset do
    Pgpeek.ProbeRepo.query("SELECT stats_reset FROM pg_stat_statements_info")
  end

  defp parse_stats_reset(%Postgrex.Result{rows: [[nil]]}), do: nil
  defp parse_stats_reset(%Postgrex.Result{rows: [[ts]]}), do: ts
  defp parse_stats_reset(_), do: nil

  defp columns_to_maps(%Postgrex.Result{columns: columns, rows: rows}) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  defp broadcast_snapshot(snapshot) do
    Phoenix.PubSub.broadcast(
      Pgpeek.PubSub,
      "snapshots",
      {:new_snapshot, snapshot.id}
    )
  end
end
