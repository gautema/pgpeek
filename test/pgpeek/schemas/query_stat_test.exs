defmodule Pgpeek.Schemas.QueryStatTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Schemas.QueryStat

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        QueryStat.changeset(%QueryStat{}, %{
          query_id: "12345",
          snapshot_id: 1,
          calls: 100,
          mean_exec_time: 1.5,
          total_exec_time: 150.0
        })

      assert changeset.valid?
    end

    test "requires query_id" do
      changeset = QueryStat.changeset(%QueryStat{}, %{snapshot_id: 1})
      refute changeset.valid?
    end

    test "requires snapshot_id" do
      changeset = QueryStat.changeset(%QueryStat{}, %{query_id: "12345"})
      refute changeset.valid?
    end
  end
end
