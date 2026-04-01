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

  Uses a PREPARE/EXPLAIN/DEALLOCATE sequence because pg_stat_statements
  queries contain $N placeholders that Postgrex would otherwise try to
  bind as parameters.
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

  # Use a prepared statement to avoid Postgrex interpreting $N as bind params.
  # Steps: PREPARE with param types -> EXPLAIN the prepared stmt -> DEALLOCATE
  defp do_explain(query_text, format_opt) do
    # pg_stat_statements truncates long queries — these can't be explained
    trimmed = String.trim(query_text)

    cond do
      String.ends_with?(trimmed, "...") ->
        {:error, "Query text is truncated by pg_stat_statements and cannot be explained. Increase track_activity_query_size in postgresql.conf."}

      true ->
        run_explain_sequence(query_text, format_opt)
    end
  end

  defp run_explain_sequence(query_text, format_opt) do
    param_types = extract_param_types(query_text)
    type_list = if param_types == "", do: "", else: "(#{param_types})"
    plan_name = "pgpeek_explain_#{:erlang.unique_integer([:positive])}"

    prepare_sql = "PREPARE #{plan_name} #{type_list} AS #{query_text}"
    explain_sql = "EXPLAIN (GENERIC_PLAN, #{format_opt}) EXECUTE #{plan_name}"
    deallocate_sql = "DEALLOCATE #{plan_name}"

    case ProbeRepo.query(prepare_sql) do
      {:ok, _} ->
        result = ProbeRepo.query(explain_sql)
        ProbeRepo.query(deallocate_sql)

        case result do
          {:ok, %Postgrex.Result{rows: rows}} ->
            plan =
              rows
              |> Enum.map(fn [line] -> line end)
              |> Enum.join("\n")

            {:ok, plan}

          {:error, error} ->
            {:error, format_error(error)}
        end

      {:error, error} ->
        # PREPARE failed — don't try to deallocate
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

  # Extract the number of $N params and generate "unknown" types for each.
  # PREPARE needs type declarations for each parameter.
  defp extract_param_types(query_text) do
    case Regex.scan(~r/\$(\d+)/, query_text) do
      [] ->
        ""

      matches ->
        max_param =
          matches
          |> Enum.map(fn [_, n] -> String.to_integer(n) end)
          |> Enum.max()

        1..max_param
        |> Enum.map(fn _ -> "unknown" end)
        |> Enum.join(", ")
    end
  end
end
