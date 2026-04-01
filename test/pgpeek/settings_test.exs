defmodule Pgpeek.SettingsTest do
  use Pgpeek.DataCase, async: false

  alias Pgpeek.Settings

  describe "get/2" do
    test "returns nil for missing key" do
      assert Settings.get("nonexistent") == nil
    end

    test "returns default for missing key" do
      assert Settings.get("nonexistent", "default") == "default"
    end

    test "returns stored value" do
      Settings.put("test_key", "test_value")
      assert Settings.get("test_key") == "test_value"
    end
  end

  describe "put/2" do
    test "creates a new setting" do
      {:ok, _} = Settings.put("new_key", "new_value")
      assert Settings.get("new_key") == "new_value"
    end

    test "updates an existing setting" do
      Settings.put("key", "value1")
      Settings.put("key", "value2")
      assert Settings.get("key") == "value2"
    end
  end

  describe "delete/1" do
    test "deletes an existing setting" do
      Settings.put("to_delete", "value")
      Settings.delete("to_delete")
      assert Settings.get("to_delete") == nil
    end

    test "no-op for missing key" do
      assert Settings.delete("nonexistent") == :ok
    end
  end

  describe "all/0" do
    test "returns all settings as a map" do
      Settings.put("a", "1")
      Settings.put("b", "2")
      all = Settings.all()
      assert all["a"] == "1"
      assert all["b"] == "2"
    end
  end
end
