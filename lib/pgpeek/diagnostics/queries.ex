defmodule Pgpeek.Diagnostics.Queries do
  @moduledoc "Query diagnostics."

  import Pgpeek.Diagnostics.Helpers

  def long_running(threshold_seconds \\ 60) do
    execute(
      """
      SELECT
        pid,
        now() - pg_stat_activity.query_start AS duration,
        EXTRACT(EPOCH FROM (now() - pg_stat_activity.query_start)) AS duration_secs,
        query,
        state,
        usename AS user,
        application_name,
        client_addr::text,
        wait_event_type,
        wait_event
      FROM pg_stat_activity
      WHERE (now() - pg_stat_activity.query_start) > interval '1 second' * $1
        AND state != 'idle'
        AND pid != pg_backend_pid()
      ORDER BY query_start
      """,
      [threshold_seconds]
    )
  end

  def outliers do
    execute("""
    SELECT
      queryid::text,
      query,
      calls,
      round(total_exec_time::numeric, 2) AS total_time_ms,
      round(mean_exec_time::numeric, 2) AS mean_time_ms,
      round(stddev_exec_time::numeric, 2) AS stddev_time_ms,
      rows,
      round((100.0 * total_exec_time / nullif(sum(total_exec_time) OVER (), 0))::numeric, 2) AS pct_total_time
    FROM pg_stat_statements
    WHERE query NOT LIKE '%pg_stat_statements%'
    ORDER BY total_exec_time DESC
    LIMIT 50
    """)
  end

  def by_calls do
    execute("""
    SELECT
      queryid::text,
      query,
      calls,
      round(total_exec_time::numeric, 2) AS total_time_ms,
      round(mean_exec_time::numeric, 2) AS mean_time_ms,
      rows
    FROM pg_stat_statements
    WHERE query NOT LIKE '%pg_stat_statements%'
    ORDER BY calls DESC
    LIMIT 50
    """)
  end
end
