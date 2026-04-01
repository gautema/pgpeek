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
  """
  def explain(query_text) when is_binary(query_text) do
    unless ProbeRepo.configured?() do
      {:error, :not_configured}
    else
      explain_sql = "EXPLAIN (GENERIC_PLAN, FORMAT TEXT) #{query_text}"

      case ProbeRepo.query(explain_sql) do
        {:ok, %Postgrex.Result{rows: rows}} ->
          plan =
            rows
            |> Enum.map(fn [line] -> line end)
            |> Enum.join("\n")

          {:ok, plan}

        {:error, %Postgrex.Error{postgres: %{message: message}}} ->
          {:error, message}

        {:error, reason} ->
          {:error, inspect(reason)}
      end
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
      explain_sql = "EXPLAIN (GENERIC_PLAN, FORMAT JSON) #{query_text}"

      case ProbeRepo.query(explain_sql) do
        {:ok, %Postgrex.Result{rows: [[json]]}} ->
          {:ok, json}

        {:error, %Postgrex.Error{postgres: %{message: message}}} ->
          {:error, message}

        {:error, reason} ->
          {:error, inspect(reason)}
      end
    end
  end

  def explain_json(nil), do: {:error, "No query text available"}
end
