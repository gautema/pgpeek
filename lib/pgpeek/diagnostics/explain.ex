defmodule Pgpeek.Diagnostics.Explain do
  @moduledoc """
  Generate query execution plans using EXPLAIN (GENERIC_PLAN).
  Requires PostgreSQL 16+.

  Never uses EXPLAIN ANALYZE — that would execute the query,
  violating the read-only principle.

  Uses a temporary PL/pgSQL function to run EXPLAIN via the simple
  query protocol, since Postgrex's extended protocol treats $N
  placeholders as bind parameters which is incompatible with
  GENERIC_PLAN queries from pg_stat_statements.
  """

  alias Pgpeek.ProbeRepo

  @create_explain_fn """
  CREATE OR REPLACE FUNCTION pg_temp.pgpeek_explain(stmt text, fmt text)
  RETURNS SETOF text LANGUAGE plpgsql AS $fn$
  DECLARE
    line text;
  BEGIN
    FOR line IN EXECUTE format('EXPLAIN (GENERIC_PLAN, %s) %s', fmt, stmt) LOOP
      RETURN NEXT line;
    END LOOP;
  END;
  $fn$
  """

  @doc """
  Run EXPLAIN on a query from pg_stat_statements.

  Uses GENERIC_PLAN so parameter placeholders ($1, $2, ...) don't
  need actual values. Returns the plan as a formatted text string.
  """
  def explain(query_text) when is_binary(query_text) do
    unless ProbeRepo.configured?() do
      {:error, :not_configured}
    else
      do_explain(query_text, "FORMAT TEXT")
    end
  end

  def explain(nil), do: {:error, "No query text available"}

  @doc """
  Run EXPLAIN with JSON output for structured plan data.
  """
  def explain_json(query_text) when is_binary(query_text) do
    unless ProbeRepo.configured?() do
      {:error, :not_configured}
    else
      do_explain(query_text, "FORMAT JSON")
    end
  end

  def explain_json(nil), do: {:error, "No query text available"}

  defp do_explain(query_text, format_opt) do
    trimmed = String.trim(query_text)

    cond do
      String.ends_with?(trimmed, "...") ->
        {:error,
         "Query text is truncated by pg_stat_statements and cannot be explained. Increase track_activity_query_size in postgresql.conf."}

      true ->
        run_explain(query_text, format_opt)
    end
  end

  # Uses a pg_temp function so PL/pgSQL's EXECUTE runs the EXPLAIN
  # via the simple query protocol, avoiding Postgrex's extended
  # protocol which interprets $N as bind parameters.
  defp run_explain(query_text, format_opt) do
    ProbeRepo.with_conn(fn conn ->
      case Postgrex.query(conn, @create_explain_fn, [], mode: :savepoint) do
        {:ok, _} ->
          Postgrex.query(
            conn,
            "SELECT * FROM pg_temp.pgpeek_explain($1, $2)",
            [query_text, format_opt],
            mode: :savepoint
          )

        {:error, error} ->
          {:error, error}
      end
    end)
    |> case do
      {:ok, %Postgrex.Result{rows: rows}} ->
        plan = rows |> Enum.map(fn [line] -> line end) |> Enum.join("\n")
        {:ok, plan}

      {:error, error} ->
        {:error, format_error(error)}
    end
  end

  defp format_error(%Postgrex.Error{postgres: %{message: message, code: code}}) do
    case code do
      "25006" ->
        "Cannot explain write queries (INSERT/UPDATE/DELETE) on a read-only connection."

      "42601" ->
        "Syntax error — this query may use internal syntax that cannot be explained: #{message}"

      _ ->
        message
    end
  end

  defp format_error(%Postgrex.Error{postgres: %{message: message}}), do: message
  defp format_error(reason), do: inspect(reason)
end
