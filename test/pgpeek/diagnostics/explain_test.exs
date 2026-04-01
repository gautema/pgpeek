defmodule Pgpeek.Diagnostics.ExplainTest do
  use ExUnit.Case, async: true

  alias Pgpeek.Diagnostics.Explain

  describe "explain/1" do
    test "returns not_configured when ProbeRepo has no URL" do
      assert {:error, :not_configured} = Explain.explain("SELECT 1")
    end

    test "returns error for nil query text" do
      assert {:error, "No query text available"} = Explain.explain(nil)
    end
  end

  describe "explain_json/1" do
    test "returns not_configured when ProbeRepo has no URL" do
      assert {:error, :not_configured} = Explain.explain_json("SELECT 1")
    end

    test "returns error for nil query text" do
      assert {:error, "No query text available"} = Explain.explain_json(nil)
    end
  end
end
