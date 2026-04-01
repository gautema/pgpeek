defmodule Pgpeek.Diagnostics.Health do
  @moduledoc "Database health diagnostics."

  import Pgpeek.Diagnostics.Helpers

  def cache_hit_ratio do
    execute("""
    SELECT
      sum(blks_hit) AS hits,
      sum(blks_read) AS reads,
      CASE sum(blks_hit) + sum(blks_read)
        WHEN 0 THEN 0
        ELSE round(sum(blks_hit)::numeric / (sum(blks_hit) + sum(blks_read)), 4)
      END AS ratio
    FROM pg_stat_database
    """)
  end

  def table_cache_hit do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      heap_blks_hit,
      heap_blks_read,
      CASE heap_blks_hit + heap_blks_read
        WHEN 0 THEN 1
        ELSE round(heap_blks_hit::numeric / (heap_blks_hit + heap_blks_read), 4)
      END AS ratio
    FROM pg_statio_user_tables
    ORDER BY heap_blks_read DESC
    LIMIT 50
    """)
  end

  def index_cache_hit do
    execute("""
    SELECT
      schemaname,
      relname AS table,
      indexrelname AS index,
      idx_blks_hit,
      idx_blks_read,
      CASE idx_blks_hit + idx_blks_read
        WHEN 0 THEN 1
        ELSE round(idx_blks_hit::numeric / (idx_blks_hit + idx_blks_read), 4)
      END AS ratio
    FROM pg_statio_user_indexes
    ORDER BY idx_blks_read DESC
    LIMIT 50
    """)
  end
end
