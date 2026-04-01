defmodule Pgpeek.Diagnostics.Helpers do
  @moduledoc "Shared helpers for diagnostic queries."

  def execute(sql, params \\ []) do
    unless Pgpeek.ProbeRepo.configured?() do
      {:error, :not_configured}
    else
      case Pgpeek.ProbeRepo.query(sql, params) do
        {:ok, %Postgrex.Result{columns: columns, rows: rows}} ->
          maps =
            Enum.map(rows, fn row ->
              columns
              |> Enum.zip(row)
              |> Map.new()
            end)

          {:ok, maps}

        {:error, _} = error ->
          error
      end
    end
  end
end
