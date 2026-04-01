defmodule Pgpeek.Diagnostics.HelpersTest do
  # Cannot be async since we modify application config
  use ExUnit.Case, async: false

  alias Pgpeek.Diagnostics.Helpers

  setup do
    original = Application.get_env(:pgpeek, Pgpeek.ProbeRepo)
    Application.put_env(:pgpeek, Pgpeek.ProbeRepo, [])
    on_exit(fn -> Application.put_env(:pgpeek, Pgpeek.ProbeRepo, original || []) end)
    :ok
  end

  describe "execute/2" do
    test "returns not_configured when ProbeRepo has no URL" do
      assert {:error, :not_configured} = Helpers.execute("SELECT 1")
    end
  end
end
