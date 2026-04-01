defmodule Pgpeek.Schemas.SnapshotTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Schemas.Snapshot

  describe "changeset/2" do
    test "valid with captured_at" do
      changeset = Snapshot.changeset(%Snapshot{}, %{captured_at: DateTime.utc_now()})
      assert changeset.valid?
    end

    test "valid with captured_at and stats_reset_at" do
      changeset =
        Snapshot.changeset(%Snapshot{}, %{
          captured_at: DateTime.utc_now(),
          stats_reset_at: DateTime.utc_now()
        })

      assert changeset.valid?
    end

    test "requires captured_at" do
      changeset = Snapshot.changeset(%Snapshot{}, %{})
      refute changeset.valid?
    end
  end
end
