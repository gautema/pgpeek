defmodule PgpeekWeb.QueryDetailLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Snapshots

  @impl true
  def mount(%{"query_id" => query_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pgpeek.PubSub, "snapshots")
    end

    socket =
      socket
      |> assign(:page_title, "Query Detail")
      |> assign(:query_id, query_id)
      |> load_query_data()

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_snapshot, _id}, socket) do
    {:noreply, load_query_data(socket)}
  end

  defp load_query_data(socket) do
    query_id = socket.assigns.query_id
    history = Snapshots.query_history(query_id)

    latest =
      case history do
        [h | _] -> h
        [] -> nil
      end

    # Get the full query text from the latest snapshot
    query_text = get_query_text(query_id)

    socket
    |> assign(:history, history)
    |> assign(:latest, latest)
    |> assign(:query_text, query_text)
  end

  defp get_query_text(query_id) do
    snapshot = Snapshots.get_latest_snapshot()

    if snapshot do
      import Ecto.Query

      Pgpeek.Schemas.QueryStat
      |> where(snapshot_id: ^snapshot.id, query_id: ^query_id)
      |> select([q], q.query_text)
      |> Pgpeek.Repo.one()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <.link navigate={~p"/queries"} class="text-sm text-blue-600 hover:text-blue-700">
          &larr; Back to queries
        </.link>
        <h1 class="mt-2 text-2xl font-bold text-zinc-900">Query Detail</h1>
      </div>

      <!-- Full query text -->
      <div class="rounded-lg border border-zinc-200 bg-white p-6">
        <h2 class="mb-3 text-sm font-medium uppercase text-zinc-500">Query Text</h2>
        <pre class="overflow-x-auto rounded bg-zinc-50 p-4 text-sm font-mono text-zinc-800"><%= @query_text || "(not available)" %></pre>
      </div>

      <!-- Current stats -->
      <%= if @latest do %>
        <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <.mini_stat label="Mean Time" value={format_time(@latest.mean_exec_time)} />
          <.mini_stat label="Total Time" value={format_time(@latest.total_exec_time)} />
          <.mini_stat label="Calls" value={format_number(@latest.calls)} />
          <.mini_stat label="Rows" value={format_number(@latest.rows)} />
        </div>
      <% end %>

      <!-- Trend table -->
      <div class="rounded-lg border border-zinc-200 bg-white">
        <div class="border-b border-zinc-200 px-6 py-4">
          <h2 class="text-lg font-semibold text-zinc-900">History (last <%= length(@history) %> snapshots)</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-zinc-200">
            <thead class="bg-zinc-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Time</th>
                <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Mean Time</th>
                <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Total Time</th>
                <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Calls</th>
                <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Rows</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 bg-white">
              <%= for h <- @history do %>
                <tr class="hover:bg-zinc-50">
                  <td class="whitespace-nowrap px-6 py-3 text-sm text-zinc-700">
                    <%= Calendar.strftime(h.captured_at, "%Y-%m-%d %H:%M") %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-3 text-right text-sm text-zinc-700">
                    <%= format_time(h.mean_exec_time) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-3 text-right text-sm text-zinc-700">
                    <%= format_time(h.total_exec_time) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-3 text-right text-sm text-zinc-700">
                    <%= format_number(h.calls) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-3 text-right text-sm text-zinc-700">
                    <%= format_number(h.rows) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @history == [] do %>
            <div class="px-6 py-12 text-center text-zinc-500">
              No history for this query yet.
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp mini_stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-4">
      <p class="text-xs font-medium text-zinc-500"><%= @label %></p>
      <p class="mt-1 text-xl font-bold text-zinc-900"><%= @value %></p>
    </div>
    """
  end

  defp format_time(nil), do: "-"
  defp format_time(ms) when ms >= 1_000, do: "#{Float.round(ms / 1_000, 2)}s"
  defp format_time(ms), do: "#{Float.round(ms * 1.0, 2)}ms"

  defp format_number(nil), do: "-"
  defp format_number(n) when is_integer(n) and n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: to_string(n)
end
