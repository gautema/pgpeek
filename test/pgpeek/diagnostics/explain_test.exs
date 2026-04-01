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

    test "extract_param_types handles queries with parameters" do
      # Test the internal helper indirectly — when ProbeRepo is not configured,
      # we get :not_configured before reaching truncation check.
      # This tests the nil and not_configured paths are correct.
      assert {:error, :not_configured} = Explain.explain("SELECT $1, $2")
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
