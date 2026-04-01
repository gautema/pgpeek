defmodule Pgpeek.Diagnostics.HelpersTest do
  use ExUnit.Case, async: true

  alias Pgpeek.Diagnostics.Helpers

  describe "execute/2" do
    test "returns not_configured error when ProbeRepo has no URL" do
      assert {:error, :not_configured} = Helpers.execute("SELECT 1")
    end
  end
end
