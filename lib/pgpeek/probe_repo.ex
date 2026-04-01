defmodule Pgpeek.ProbeRepo do
  @moduledoc """
  Read-only Postgrex connection to the monitored Postgres database.
  This is NOT an Ecto repo — it's a raw Postgrex connection pool
  to avoid any accidental writes.
  """

  def child_spec(_opts) do
    config = Application.get_env(:pgpeek, __MODULE__, [])
    url = Keyword.get(config, :url)

    if url do
      parsed = URI.parse(url)
      userinfo = String.split(parsed.userinfo || "", ":")
      username = Enum.at(userinfo, 0)
      password = Enum.at(userinfo, 1)
      database = String.trim_leading(parsed.path || "", "/")

      child_opts = [
        name: __MODULE__,
        hostname: parsed.host,
        port: parsed.port || 5432,
        username: username,
        password: password,
        database: database,
        pool_size: 3,
        parameters: [application_name: "pgpeek"]
      ]

      %{
        id: __MODULE__,
        start: {Postgrex, :start_link, [child_opts]},
        type: :worker
      }
    else
      # Return a dummy spec that does nothing when no URL is configured
      %{
        id: __MODULE__,
        start: {Agent, :start_link, [fn -> nil end, [name: __MODULE__]]},
        type: :worker
      }
    end
  end

  @doc "Execute a read-only query against the monitored database."
  def query(sql, params \\ []) do
    Postgrex.query(__MODULE__, sql, params)
  end

  @doc "Check if we have a real Postgres connection configured."
  def configured? do
    config = Application.get_env(:pgpeek, __MODULE__, [])
    Keyword.has_key?(config, :url)
  end
end
