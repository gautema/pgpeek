defmodule Pgpeek.Schemas.AlertTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Schemas.Alert

  describe "changeset/2" do
    test "valid with all required fields" do
      changeset =
        Alert.changeset(%Alert{}, %{
          metric: "mean_exec_time",
          threshold: 100.0,
          channel: "slack",
          destination: "#alerts"
        })

      assert changeset.valid?
    end

    test "requires metric" do
      changeset =
        Alert.changeset(%Alert{}, %{threshold: 100.0, channel: "slack", destination: "#alerts"})

      refute changeset.valid?
    end

    test "requires threshold" do
      changeset =
        Alert.changeset(%Alert{}, %{metric: "mean_exec_time", channel: "slack", destination: "#alerts"})

      refute changeset.valid?
    end

    test "requires channel" do
      changeset =
        Alert.changeset(%Alert{}, %{metric: "mean_exec_time", threshold: 100.0, destination: "#alerts"})

      refute changeset.valid?
    end

    test "requires destination" do
      changeset =
        Alert.changeset(%Alert{}, %{metric: "mean_exec_time", threshold: 100.0, channel: "slack"})

      refute changeset.valid?
    end
  end
end
