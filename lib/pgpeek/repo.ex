defmodule Pgpeek.Repo do
  use Ecto.Repo,
    otp_app: :pgpeek,
    adapter: Ecto.Adapters.SQLite3
end
