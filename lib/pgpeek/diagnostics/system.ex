defmodule Pgpeek.Diagnostics.System do
  @moduledoc "System-level diagnostics."

  import Pgpeek.Diagnostics.Helpers

  def db_settings do
    execute("""
    SELECT
      name,
      setting,
      unit,
      short_desc AS description,
      source
    FROM pg_settings
    WHERE name IN (
      'max_connections', 'shared_buffers', 'effective_cache_size',
      'work_mem', 'maintenance_work_mem', 'wal_buffers',
      'checkpoint_completion_target', 'random_page_cost',
      'effective_io_concurrency', 'max_worker_processes',
      'max_parallel_workers_per_gather', 'max_parallel_workers',
      'autovacuum', 'autovacuum_max_workers',
      'statement_timeout', 'lock_timeout', 'idle_in_transaction_session_timeout',
      'log_min_duration_statement', 'track_activity_query_size',
      'default_statistics_target', 'jit'
    )
    ORDER BY name
    """)
  end

  def extensions do
    execute("""
    SELECT
      extname AS name,
      extversion AS version,
      n.nspname AS schema
    FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace
    ORDER BY extname
    """)
  end

  def database_size do
    execute("""
    SELECT
      current_database() AS database,
      pg_size_pretty(pg_database_size(current_database())) AS size,
      pg_database_size(current_database()) AS size_bytes
    """)
  end

  def missing_fk_constraints do
    execute("""
    SELECT
      c.table_schema AS schemaname,
      c.table_name AS table,
      c.column_name AS column,
      c.data_type
    FROM information_schema.columns c
    WHERE c.column_name LIKE '%_id'
      AND c.table_schema NOT IN ('pg_catalog', 'information_schema')
      AND c.data_type IN ('integer', 'bigint', 'smallint', 'uuid')
      AND NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND kcu.table_schema = c.table_schema
          AND kcu.table_name = c.table_name
          AND kcu.column_name = c.column_name
      )
      AND NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND kcu.table_schema = c.table_schema
          AND kcu.table_name = c.table_name
          AND kcu.column_name = c.column_name
      )
    ORDER BY c.table_schema, c.table_name, c.column_name
    """)
  end
end
