defmodule Pgpeek.DataCase do
  @moduledoc """
  This module defines the test case for tests that
  require database access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Pgpeek.Repo
      import Ecto
      import Ecto.Query
      import Pgpeek.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Pgpeek.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
