defmodule Pgpeek.Diagnostics.ExplainTest do
  use ExUnit.Case, async: false

  alias Pgpeek.Diagnostics.Explain

  setup do
    original = Application.get_env(:pgpeek, Pgpeek.ProbeRepo)
    Application.put_env(:pgpeek, Pgpeek.ProbeRepo, [])
    on_exit(fn -> Application.put_env(:pgpeek, Pgpeek.ProbeRepo, original || []) end)
    :ok
  end

  describe "explain/1" do
    test "returns not_configured when ProbeRepo has no URL" do
      assert {:error, :not_configured} = Explain.explain("SELECT 1")
    end

    test "returns error for nil query text" do
      assert {:error, "No query text available"} = Explain.explain(nil)
    end

    test "returns not_configured for queries with parameters" do
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
