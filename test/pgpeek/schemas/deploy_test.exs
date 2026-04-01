defmodule Pgpeek.Schemas.DeployTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Schemas.Deploy

  describe "changeset/2" do
    test "valid with deployed_at" do
      changeset = Deploy.changeset(%Deploy{}, %{deployed_at: DateTime.utc_now()})
      assert changeset.valid?
    end

    test "valid with description and deployed_at" do
      changeset =
        Deploy.changeset(%Deploy{}, %{
          description: "v1.2.3 release",
          deployed_at: DateTime.utc_now()
        })

      assert changeset.valid?
    end

    test "requires deployed_at" do
      changeset = Deploy.changeset(%Deploy{}, %{description: "release"})
      refute changeset.valid?
    end
  end
end
