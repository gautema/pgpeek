defmodule Pgpeek.DiagnosticsTest do
  use ExUnit.Case, async: true

  alias Pgpeek.Diagnostics

  # Without a real Postgres connection, all diagnostics return {:error, :not_configured}.
  # These tests verify the facade delegates correctly to all sub-modules.

  describe "health" do
    test "cache_hit_ratio/0" do
      assert {:error, :not_configured} = Diagnostics.cache_hit_ratio()
    end

    test "table_cache_hit/0" do
      assert {:error, :not_configured} = Diagnostics.table_cache_hit()
    end

    test "index_cache_hit/0" do
      assert {:error, :not_configured} = Diagnostics.index_cache_hit()
    end
  end

  describe "indexes" do
    test "missing_fk_indexes/0" do
      assert {:error, :not_configured} = Diagnostics.missing_fk_indexes()
    end

    test "unused_indexes/0" do
      assert {:error, :not_configured} = Diagnostics.unused_indexes()
    end

    test "duplicate_indexes/0" do
      assert {:error, :not_configured} = Diagnostics.duplicate_indexes()
    end

    test "null_indexes/0" do
      assert {:error, :not_configured} = Diagnostics.null_indexes()
    end

    test "index_usage/0" do
      assert {:error, :not_configured} = Diagnostics.index_usage()
    end

    test "index_sizes/0" do
      assert {:error, :not_configured} = Diagnostics.index_sizes()
    end
  end

  describe "tables" do
    test "table_sizes/0" do
      assert {:error, :not_configured} = Diagnostics.table_sizes()
    end

    test "vacuum_stats/0" do
      assert {:error, :not_configured} = Diagnostics.vacuum_stats()
    end

    test "seq_scans/0" do
      assert {:error, :not_configured} = Diagnostics.seq_scans()
    end

    test "records_rank/0" do
      assert {:error, :not_configured} = Diagnostics.records_rank()
    end

    test "table_schema/1" do
      assert {:error, :not_configured} = Diagnostics.table_schema("users")
    end

    test "table_foreign_keys/1" do
      assert {:error, :not_configured} = Diagnostics.table_foreign_keys("users")
    end
  end

  describe "queries" do
    test "long_running_queries/0" do
      assert {:error, :not_configured} = Diagnostics.long_running_queries()
    end

    test "long_running_queries/1" do
      assert {:error, :not_configured} = Diagnostics.long_running_queries(30)
    end

    test "query_outliers/0" do
      assert {:error, :not_configured} = Diagnostics.query_outliers()
    end

    test "query_calls/0" do
      assert {:error, :not_configured} = Diagnostics.query_calls()
    end
  end

  describe "connections" do
    test "current_connections/0" do
      assert {:error, :not_configured} = Diagnostics.current_connections()
    end

    test "connection_summary/0" do
      assert {:error, :not_configured} = Diagnostics.connection_summary()
    end

    test "locks/0" do
      assert {:error, :not_configured} = Diagnostics.locks()
    end

    test "blocking_queries/0" do
      assert {:error, :not_configured} = Diagnostics.blocking_queries()
    end

    test "all_locks/0" do
      assert {:error, :not_configured} = Diagnostics.all_locks()
    end
  end

  describe "system" do
    test "db_settings/0" do
      assert {:error, :not_configured} = Diagnostics.db_settings()
    end

    test "extensions/0" do
      assert {:error, :not_configured} = Diagnostics.extensions()
    end

    test "database_size/0" do
      assert {:error, :not_configured} = Diagnostics.database_size()
    end

    test "missing_fk_constraints/0" do
      assert {:error, :not_configured} = Diagnostics.missing_fk_constraints()
    end
  end
end
