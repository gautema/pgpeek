defmodule Pgpeek.ProbeRepoTest do
  use ExUnit.Case, async: true

  alias Pgpeek.ProbeRepo

  setup do
    original = Application.get_env(:pgpeek, ProbeRepo)
    on_exit(fn -> Application.put_env(:pgpeek, ProbeRepo, original || []) end)
    %{original: original}
  end

  describe "configured?/0" do
    test "returns true when url is configured" do
      Application.put_env(:pgpeek, ProbeRepo, url: "postgres://localhost/test")
      assert ProbeRepo.configured?()
    end

    test "returns false when no url is configured" do
      Application.put_env(:pgpeek, ProbeRepo, [])
      refute ProbeRepo.configured?()
    end
  end

  describe "child_spec/1" do
    test "returns Postgrex spec when url is configured" do
      Application.put_env(:pgpeek, ProbeRepo, url: "postgres://user:pass@localhost:5432/mydb")

      spec = ProbeRepo.child_spec([])
      assert spec.id == ProbeRepo
      assert {Postgrex, :start_link, [opts]} = spec.start
      assert opts[:hostname] == "localhost"
      assert opts[:port] == 5432
      assert opts[:username] == "user"
      assert opts[:password] == "pass"
      assert opts[:database] == "mydb"
    end

    test "returns Agent spec when no url configured" do
      Application.put_env(:pgpeek, ProbeRepo, [])

      spec = ProbeRepo.child_spec([])
      assert spec.id == ProbeRepo
      assert {Agent, :start_link, _} = spec.start
    end
  end
end
