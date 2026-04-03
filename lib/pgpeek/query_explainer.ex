defmodule Pgpeek.QueryExplainer do
  @moduledoc """
  Uses an LLM to explain SQL queries in plain English and suggest optimizations.
  Supports any provider via req_llm (OpenAI, Anthropic, Ollama, etc).

  Configuration priority:
    1. Settings in SQLite (configured via UI at /settings)
    2. LLM_MODEL environment variable
  """

  @system_prompt """
  You are a PostgreSQL performance expert. You will be given a SQL query captured from pg_stat_statements.

  Respond with two sections:

  **What this query does**
  Explain in 1-3 plain English sentences what the query does. Mention which tables and columns are involved. Be concise and clear for someone who didn't write the query.

  **Optimization suggestions**
  If you see potential improvements, list them as bullet points. Consider:
  - Missing indexes (mention the specific columns)
  - N+1 patterns
  - Unnecessary columns in SELECT
  - Better join strategies
  - Opportunities to use partial indexes or covering indexes

  If the query looks well-optimized, say so. Don't invent problems that aren't there.

  Keep your total response under 300 words. Use markdown formatting.
  """

  @doc """
  Explain a query using the configured LLM.
  Returns `{:ok, explanation}` or `{:error, reason}`.
  """
  def explain(query_text, opts \\ [])

  def explain(query_text, opts) when is_binary(query_text) do
    case config() do
      {:ok, model, api_key} ->
        if api_key, do: set_api_key(model, api_key)
        do_explain(model, query_text, opts)

      :not_configured ->
        {:error, :not_configured}
    end
  end

  def explain(nil, _opts), do: {:error, "No query text available"}

  @doc """
  Get AI advice on diagnostic results.
  Takes the check name, description, and result rows, and asks
  the LLM for actionable recommendations.
  """
  def advise_diagnostic(check_label, check_desc, results) when is_list(results) do
    case config() do
      {:ok, model, api_key} ->
        if api_key, do: set_api_key(model, api_key)
        do_advise(model, check_label, check_desc, results)

      :not_configured ->
        {:error, :not_configured}
    end
  end

  @doc "Check if an LLM is configured."
  def configured? do
    config() != :not_configured
  end

  @doc "Test the LLM connection with a simple prompt."
  def test_connection(model, api_key) do
    if api_key && api_key != "", do: set_api_key(model, api_key)

    context =
      ReqLLM.Context.new([
        ReqLLM.Context.user("Reply with exactly: OK")
      ])

    case ReqLLM.generate_text(model, context, max_tokens: 10, temperature: 0.0) do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  defp config do
    # Priority: SQLite settings > env var
    db_model = Pgpeek.Settings.get("llm_model")
    db_api_key = Pgpeek.Settings.get("llm_api_key")
    env_model = Application.get_env(:pgpeek, :llm_model)

    cond do
      db_model && db_model != "" -> {:ok, db_model, db_api_key}
      env_model -> {:ok, env_model, nil}
      true -> :not_configured
    end
  end

  defp set_api_key(model, api_key) do
    provider =
      case String.split(model, ":", parts: 2) do
        [p, _] -> p
        _ -> nil
      end

    key_name =
      case provider do
        "anthropic" -> :anthropic_api_key
        "openai" -> :openai_api_key
        "google" -> :google_api_key
        "groq" -> :groq_api_key
        "xai" -> :xai_api_key
        "mistral" -> :mistral_api_key
        _ -> nil
      end

    if key_name, do: ReqLLM.put_key(key_name, api_key)
  end

  defp do_advise(model, check_label, check_desc, results) do
    # Summarize results — send at most 20 rows to avoid blowing token limits
    summary =
      results
      |> Enum.take(20)
      |> Enum.map(fn row ->
        row
        |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
        |> Enum.join(", ")
      end)
      |> Enum.join("\n")

    total = length(results)
    truncated = if total > 20, do: " (showing 20 of #{total})", else: ""

    context =
      ReqLLM.Context.new([
        ReqLLM.Context.system("""
        You are a PostgreSQL DBA expert. You will be shown the results of a diagnostic check
        run against a production PostgreSQL database.

        Give clear, actionable advice:
        - What do these results mean?
        - What should the user do about it? Be specific — include SQL commands where relevant.
        - Which items are most urgent?
        - Which are safe to ignore?

        Be concise. Use markdown. Keep it under 400 words.
        """),
        ReqLLM.Context.user("""
        Diagnostic: **#{check_label}**
        Description: #{check_desc}

        Results#{truncated}:
        ```
        #{summary}
        ```
        """)
      ])

    case ReqLLM.generate_text(model, context, max_tokens: 1500, temperature: 0.3) do
      {:ok, response} ->
        {:ok, extract_content(response)}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp do_explain(model, query_text, opts) do
    plan = Keyword.get(opts, :explain_plan)
    stats = Keyword.get(opts, :stats)

    extra_context = build_extra_context(plan, stats)

    context =
      ReqLLM.Context.new([
        ReqLLM.Context.system(@system_prompt),
        ReqLLM.Context.user(
          "Explain this PostgreSQL query:\n\n```sql\n#{query_text}\n```#{extra_context}"
        )
      ])

    case ReqLLM.generate_text(model, context, max_tokens: 8000, temperature: 0.3) do
      {:ok, response} ->
        {:ok, extract_content(response)}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_extra_context(plan, stats) do
    parts = []

    parts =
      if plan do
        ["\n\n**Execution plan (GENERIC_PLAN):**\n```\n#{plan}\n```" | parts]
      else
        parts
      end

    parts =
      if stats do
        summary =
          "Mean time: #{stats.mean_exec_time}ms, Total time: #{stats.total_exec_time}ms, " <>
            "Calls: #{stats.calls}, Rows: #{stats.rows}"

        ["\n\n**Current stats:** #{summary}" | parts]
      else
        parts
      end

    parts |> Enum.reverse() |> Enum.join("")
  end

  defp extract_content(%{message: %{content: content}}) when is_binary(content), do: content

  defp extract_content(%{message: %{content: parts}}) when is_list(parts) do
    parts
    |> Enum.map(fn
      %{text: text} -> text
      other -> inspect(other)
    end)
    |> Enum.join("")
  end

  defp extract_content(response) do
    inspect(response)
  end

  defp format_error(%{message: msg}) when is_binary(msg), do: msg
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
