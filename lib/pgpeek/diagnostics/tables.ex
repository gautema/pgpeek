defmodule Pgpeek.Diagnostics.Tables do
  @moduledoc "Table diagnostics."

  import Pgpeek.Diagnostics.Helpers

  def sizes do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
      pg_total_relation_size(relid) AS total_size_bytes,
      pg_size_pretty(pg_relation_size(relid)) AS table_size,
      pg_relation_size(relid) AS table_size_bytes,
      pg_size_pretty(pg_indexes_size(relid)) AS indexes_size,
      pg_indexes_size(relid) AS indexes_size_bytes
    FROM pg_stat_user_tables
    ORDER BY pg_total_relation_size(relid) DESC
    LIMIT 100
    """)
  end

  def vacuum_stats do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      n_live_tup AS live_tuples,
      n_dead_tup AS dead_tuples,
      CASE n_live_tup WHEN 0 THEN 0
        ELSE round(100.0 * n_dead_tup / n_live_tup, 1)
      END AS dead_pct,
      last_vacuum,
      last_autovacuum,
      last_analyze,
      last_autoanalyze,
      vacuum_count,
      autovacuum_count
    FROM pg_stat_user_tables
    ORDER BY n_dead_tup DESC
    LIMIT 50
    """)
  end

  def seq_scans do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      seq_scan,
      seq_tup_read,
      idx_scan,
      n_live_tup AS estimated_rows
    FROM pg_stat_user_tables
    WHERE seq_scan > 0
    ORDER BY seq_scan DESC
    LIMIT 50
    """)
  end

  def records_rank do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      n_live_tup AS estimated_rows
    FROM pg_stat_user_tables
    ORDER BY n_live_tup DESC
    LIMIT 50
    """)
  end

  def schema(table_name) do
    execute(
      """
      SELECT
        a.attname AS column,
        pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
        a.attnotnull AS not_null,
        pg_get_expr(d.adbin, d.adrelid) AS default_value,
        col_description(a.attrelid, a.attnum) AS comment
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
      WHERE a.attrelid = $1::regclass
        AND a.attnum > 0
        AND NOT a.attisdropped
      ORDER BY a.attnum
      """,
      [table_name]
    )
  end

  def foreign_keys(table_name) do
    execute(
      """
      SELECT
        conname AS constraint_name,
        conrelid::regclass AS table,
        array_to_string(array(SELECT attname FROM pg_attribute WHERE attrelid = conrelid AND attnum = ANY(conkey)), ', ') AS columns,
        confrelid::regclass AS referenced_table,
        array_to_string(array(SELECT attname FROM pg_attribute WHERE attrelid = confrelid AND attnum = ANY(confkey)), ', ') AS referenced_columns
      FROM pg_constraint
      WHERE contype = 'f'
        AND (conrelid = $1::regclass OR confrelid = $1::regclass)
      ORDER BY conname
      """,
      [table_name]
    )
  end
end
