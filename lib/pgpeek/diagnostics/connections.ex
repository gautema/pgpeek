defmodule Pgpeek.Diagnostics.Connections do
  @moduledoc "Connection and lock diagnostics."

  import Pgpeek.Diagnostics.Helpers

  def current do
    execute("""
    SELECT
      usename AS user,
      application_name,
      client_addr::text,
      state,
      count(*) AS count
    FROM pg_stat_activity
    WHERE pid != pg_backend_pid()
    GROUP BY usename, application_name, client_addr, state
    ORDER BY count DESC
    """)
  end

  def summary do
    execute("""
    SELECT
      (SELECT count(*) FROM pg_stat_activity) AS total_connections,
      (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_connections,
      (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle') AS idle,
      (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') AS active,
      (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction') AS idle_in_transaction
    """)
  end

  def locks do
    execute("""
    SELECT
      pg_locks.pid,
      pg_stat_activity.usename AS user,
      pg_stat_activity.query,
      pg_locks.mode,
      pg_locks.locktype,
      pg_locks.granted,
      pg_locks.relation::regclass::text AS relation,
      now() - pg_stat_activity.query_start AS duration
    FROM pg_locks
    JOIN pg_stat_activity ON pg_locks.pid = pg_stat_activity.pid
    WHERE pg_stat_activity.pid != pg_backend_pid()
      AND NOT pg_locks.granted
    ORDER BY pg_stat_activity.query_start
    """)
  end

  def blocking do
    execute("""
    SELECT
      blocked_locks.pid AS blocked_pid,
      blocked_activity.usename AS blocked_user,
      blocked_activity.query AS blocked_query,
      now() - blocked_activity.query_start AS blocked_duration,
      blocking_locks.pid AS blocking_pid,
      blocking_activity.usename AS blocking_user,
      blocking_activity.query AS blocking_query,
      now() - blocking_activity.query_start AS blocking_duration
    FROM pg_locks blocked_locks
    JOIN pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_locks blocking_locks
      ON blocking_locks.locktype = blocked_locks.locktype
      AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
      AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
      AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
      AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
      AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
      AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
      AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
      AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
      AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
      AND blocking_locks.pid != blocked_locks.pid
    JOIN pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
    WHERE NOT blocked_locks.granted
    ORDER BY blocked_activity.query_start
    """)
  end

  def all_locks do
    execute("""
    SELECT
      l.pid,
      a.usename AS user,
      a.application_name,
      l.locktype,
      l.mode,
      l.granted,
      l.relation::regclass::text AS relation,
      a.state,
      a.query,
      now() - a.query_start AS duration
    FROM pg_locks l
    JOIN pg_stat_activity a ON l.pid = a.pid
    WHERE a.pid != pg_backend_pid()
    ORDER BY l.granted, a.query_start
    LIMIT 200
    """)
  end
end
