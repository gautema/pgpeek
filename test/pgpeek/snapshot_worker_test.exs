defmodule Pgpeek.SnapshotWorkerTest do
  use Pgpeek.DataCase, async: false

  alias Pgpeek.SnapshotWorker

  # The SnapshotWorker is started by the application supervisor.

  test "worker is alive after boot" do
    pid = Process.whereis(SnapshotWorker)
    assert pid
    assert Process.alive?(pid)
  end

  test "state has default interval" do
    state = :sys.get_state(SnapshotWorker)
    assert state.interval == 300_000
  end

  test "state starts with nil last_stats_reset" do
    state = :sys.get_state(SnapshotWorker)
    assert state.last_stats_reset == nil
  end

  test "trigger_snapshot/0 returns :ok without crashing" do
    # Without ProbeRepo configured, this is a no-op
    assert :ok = SnapshotWorker.trigger_snapshot()
    # Give the cast time to process
    _ = :sys.get_state(SnapshotWorker)
    assert Process.alive?(Process.whereis(SnapshotWorker))
  end
end
