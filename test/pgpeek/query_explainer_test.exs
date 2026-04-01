defmodule Pgpeek.QueryExplainerTest do
  use ExUnit.Case, async: false

  alias Pgpeek.QueryExplainer

  setup do
    original = Application.get_env(:pgpeek, :llm_model)
    on_exit(fn -> Application.put_env(:pgpeek, :llm_model, original) end)
    :ok
  end

  describe "configured?/0" do
    test "returns false when no LLM model is set" do
      Application.delete_env(:pgpeek, :llm_model)
      refute QueryExplainer.configured?()
    end

    test "returns true when LLM model is set" do
      Application.put_env(:pgpeek, :llm_model, "anthropic:claude-haiku-4-5")
      assert QueryExplainer.configured?()
    end
  end

  describe "explain/1" do
    test "returns not_configured when no LLM model is set" do
      Application.delete_env(:pgpeek, :llm_model)
      assert {:error, :not_configured} = QueryExplainer.explain("SELECT 1")
    end

    test "returns error for nil query text" do
      assert {:error, "No query text available"} = QueryExplainer.explain(nil)
    end
  end
end
