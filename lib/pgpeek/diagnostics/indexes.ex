defmodule Pgpeek.Diagnostics.Indexes do
  @moduledoc "Index diagnostics."

  import Pgpeek.Diagnostics.Helpers

  def missing_fk_indexes do
    execute("""
    SELECT
      c.conrelid::regclass AS table,
      a.attname AS column,
      c.conname AS constraint_name,
      c.confrelid::regclass AS referenced_table
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
    WHERE c.contype = 'f'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid = c.conrelid
          AND a.attnum = ANY(i.indkey)
      )
    ORDER BY c.conrelid::regclass::text, a.attname
    """)
  end

  def unused do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      indexrelname AS index,
      pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
      pg_relation_size(i.indexrelid) AS index_size_bytes,
      idx_scan AS scans
    FROM pg_stat_user_indexes i
    JOIN pg_index pi ON i.indexrelid = pi.indexrelid
    WHERE idx_scan = 0
      AND NOT pi.indisunique
      AND NOT pi.indisprimary
      AND schemaname NOT IN ('pg_catalog', 'pg_toast')
      AND pg_relation_size(i.indexrelid) > 8192
    ORDER BY pg_relation_size(i.indexrelid) DESC
    """)
  end

  def duplicate do
    execute("""
    SELECT
      pg_size_pretty(sum(pg_relation_size(idx))::bigint) AS total_size,
      string_agg(idx::regclass::text, ', ') AS indexes,
      (array_agg(idx))[1]::regclass::text AS keep_index,
      indrelid::regclass AS table,
      array_to_string(array_agg(pg_get_indexdef(idx) ORDER BY idx), E'\\n') AS definitions
    FROM (
      SELECT indexrelid AS idx, indrelid, indkey
      FROM pg_index
      WHERE indrelid::regclass::text NOT LIKE 'pg_%'
    ) sub
    GROUP BY indrelid, indkey
    HAVING count(*) > 1
    ORDER BY sum(pg_relation_size(idx)) DESC
    """)
  end

  def null_indexes do
    execute("""
    SELECT
      s.schemaname,
      s.relname AS table,
      s.indexrelname AS index,
      pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
      s.idx_scan AS scans,
      a.attname AS column,
      pg_get_indexdef(s.indexrelid) AS definition
    FROM pg_stat_user_indexes s
    JOIN pg_index i ON s.indexrelid = i.indexrelid
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
    WHERE array_length(i.indkey, 1) = 1
      AND NOT i.indisunique
      AND NOT a.attnotnull
      AND i.indpred IS NULL
      AND s.schemaname NOT IN ('pg_catalog', 'pg_toast')
    ORDER BY pg_relation_size(s.indexrelid) DESC
    LIMIT 50
    """)
  end

  def usage do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      seq_scan,
      idx_scan,
      CASE seq_scan + idx_scan
        WHEN 0 THEN 0
        ELSE round(100.0 * idx_scan / (seq_scan + idx_scan), 1)
      END AS idx_scan_pct,
      n_live_tup AS estimated_rows
    FROM pg_stat_user_tables
    WHERE n_live_tup > 1000
    ORDER BY
      CASE seq_scan + idx_scan
        WHEN 0 THEN 0
        ELSE round(100.0 * idx_scan / (seq_scan + idx_scan), 1)
      END ASC,
      n_live_tup DESC
    LIMIT 50
    """)
  end

  def sizes do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      indexrelname AS index,
      pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
      pg_relation_size(indexrelid) AS index_size_bytes,
      idx_scan AS scans
    FROM pg_stat_user_indexes
    ORDER BY pg_relation_size(indexrelid) DESC
    LIMIT 100
    """)
  end
end
