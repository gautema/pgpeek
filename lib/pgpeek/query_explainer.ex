defmodule Pgpeek.QueryExplainer do
  @moduledoc """
  Uses an LLM to explain SQL queries in plain English and suggest optimizations.
  Supports any provider via req_llm (OpenAI, Anthropic, Ollama, etc).

  Configure via environment variables:
    LLM_MODEL=anthropic:claude-haiku-4-5   (provider:model format)
    ANTHROPIC_API_KEY=sk-ant-...           (or OPENAI_API_KEY, etc)
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
  def explain(query_text) when is_binary(query_text) do
    model = model()

    if model do
      do_explain(model, query_text)
    else
      {:error, :not_configured}
    end
  end

  def explain(nil), do: {:error, "No query text available"}

  @doc "Check if an LLM is configured."
  def configured? do
    model() != nil
  end

  defp model do
    Application.get_env(:pgpeek, :llm_model)
  end

  defp do_explain(model, query_text) do
    context =
      ReqLLM.Context.new([
        ReqLLM.Context.system(@system_prompt),
        ReqLLM.Context.user("Explain this PostgreSQL query:\n\n```sql\n#{query_text}\n```")
      ])

    case ReqLLM.generate_text(model, context, max_tokens: 1000, temperature: 0.3) do
      {:ok, response} ->
        {:ok, extract_content(response)}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
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
