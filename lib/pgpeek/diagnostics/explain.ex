defmodule Pgpeek.Diagnostics.Explain do
  @moduledoc """
  Generate query execution plans using EXPLAIN (GENERIC_PLAN).
  Requires PostgreSQL 16+.

  Never uses EXPLAIN ANALYZE — that would execute the query,
  violating the read-only principle.
  """

  alias Pgpeek.ProbeRepo

  @doc """
  Run EXPLAIN on a query from pg_stat_statements.

  Uses GENERIC_PLAN so parameter placeholders ($1, $2, ...) don't
  need actual values. Returns the plan as a formatted text string.

  PostgreSQL 16+ supports GENERIC_PLAN directly on queries with $N
  placeholders — no PREPARE/EXECUTE needed.
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
        {:error, "Query text is truncated by pg_stat_statements and cannot be explained. Increase track_activity_query_size in postgresql.conf."}

      true ->
        run_explain(query_text, format_opt)
    end
  end

  defp run_explain(query_text, format_opt) do
    sql = "EXPLAIN (GENERIC_PLAN, #{format_opt}) #{query_text}"

    case ProbeRepo.query(sql) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        plan =
          rows
          |> Enum.map(fn [line] -> line end)
          |> Enum.join("\n")

        {:ok, plan}

      {:error, error} ->
        {:error, format_error(error)}
    end
  end

  defp format_error(%Postgrex.Error{postgres: %{message: message, code: code}}) do
    case code do
      "25006" -> "Cannot explain write queries (INSERT/UPDATE/DELETE) on a read-only connection."
      "42601" -> "Syntax error — this query may use internal syntax that cannot be prepared: #{message}"
      _ -> message
    end
  end

  defp format_error(%Postgrex.Error{postgres: %{message: message}}), do: message
  defp format_error(reason), do: inspect(reason)
end
