defmodule Pgpeek.Diagnostics do
  @moduledoc "Facade for all diagnostic queries against the monitored database."

  alias Pgpeek.Diagnostics.{Health, Indexes, Tables, Queries, Connections, System}

  # Health
  defdelegate cache_hit_ratio, to: Health
  defdelegate table_cache_hit, to: Health
  defdelegate index_cache_hit, to: Health

  # Indexes
  defdelegate missing_fk_indexes, to: Indexes
  defdelegate unused_indexes, to: Indexes, as: :unused
  defdelegate duplicate_indexes, to: Indexes, as: :duplicate
  defdelegate null_indexes, to: Indexes
  defdelegate index_usage, to: Indexes, as: :usage
  defdelegate index_sizes, to: Indexes, as: :sizes

  # Tables
  defdelegate table_sizes, to: Tables, as: :sizes
  defdelegate vacuum_stats, to: Tables
  defdelegate seq_scans, to: Tables
  defdelegate records_rank, to: Tables
  defdelegate table_schema(table_name), to: Tables, as: :schema
  defdelegate table_foreign_keys(table_name), to: Tables, as: :foreign_keys

  # Queries
  defdelegate long_running_queries, to: Queries, as: :long_running
  defdelegate long_running_queries(threshold), to: Queries, as: :long_running
  defdelegate query_outliers, to: Queries, as: :outliers
  defdelegate query_calls, to: Queries, as: :by_calls

  # Connections
  defdelegate current_connections, to: Connections, as: :current
  defdelegate connection_summary, to: Connections, as: :summary
  defdelegate locks, to: Connections
  defdelegate blocking_queries, to: Connections, as: :blocking
  defdelegate all_locks, to: Connections

  # System
  defdelegate db_settings, to: System
  defdelegate extensions, to: System
  defdelegate database_size, to: System
  defdelegate missing_fk_constraints, to: System
end
