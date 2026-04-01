defmodule PgpeekWeb.QueriesLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Snapshots

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pgpeek.PubSub, "snapshots")
    end

    socket =
      socket
      |> assign(:page_title, "Queries")
      |> assign(:sort_by, "total_exec_time")
      |> assign(:sort_dir, "desc")
      |> load_queries()

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_snapshot, _id}, socket) do
    {:noreply, load_queries(socket)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    dir =
      if socket.assigns.sort_by == field do
        if socket.assigns.sort_dir == "desc", do: "asc", else: "desc"
      else
        "desc"
      end

    socket =
      socket
      |> assign(:sort_by, field)
      |> assign(:sort_dir, dir)
      |> load_queries()

    {:noreply, socket}
  end

  defp load_queries(socket) do
    snapshot = Snapshots.get_latest_snapshot()

    queries =
      if snapshot do
        stats = Snapshots.query_stats_for_snapshot(snapshot.id)
        sort_queries(stats, socket.assigns.sort_by, socket.assigns.sort_dir)
      else
        []
      end

    socket
    |> assign(:snapshot, snapshot)
    |> assign(:queries, queries)
  end

  defp sort_queries(queries, field, dir) do
    sorter =
      case field do
        "total_exec_time" -> &(&1.total_exec_time || 0)
        "mean_exec_time" -> &(&1.mean_exec_time || 0)
        "calls" -> &(&1.calls || 0)
        "rows" -> &(&1.rows || 0)
        _ -> &(&1.total_exec_time || 0)
      end

    direction = if dir == "desc", do: :desc, else: :asc
    Enum.sort_by(queries, sorter, direction)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold text-zinc-900">All Queries</h1>
        <%= if @snapshot do %>
          <p class="text-sm text-zinc-500">
            Snapshot from <%= Calendar.strftime(@snapshot.captured_at, "%Y-%m-%d %H:%M:%S UTC") %>
          </p>
        <% end %>
      </div>

      <div class="rounded-lg border border-zinc-200 bg-white">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-zinc-200">
            <thead class="bg-zinc-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Query</th>
                <th class="cursor-pointer px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500 hover:text-zinc-700"
                    phx-click="sort" phx-value-field="total_exec_time">
                  Total Time <%= sort_indicator("total_exec_time", @sort_by, @sort_dir) %>
                </th>
                <th class="cursor-pointer px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500 hover:text-zinc-700"
                    phx-click="sort" phx-value-field="mean_exec_time">
                  Mean Time <%= sort_indicator("mean_exec_time", @sort_by, @sort_dir) %>
                </th>
                <th class="cursor-pointer px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500 hover:text-zinc-700"
                    phx-click="sort" phx-value-field="calls">
                  Calls <%= sort_indicator("calls", @sort_by, @sort_dir) %>
                </th>
                <th class="cursor-pointer px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500 hover:text-zinc-700"
                    phx-click="sort" phx-value-field="rows">
                  Rows <%= sort_indicator("rows", @sort_by, @sort_dir) %>
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Cache Hit %</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 bg-white">
              <%= for query <- @queries do %>
                <tr class="hover:bg-zinc-50">
                  <td class="max-w-lg truncate px-6 py-4 text-sm font-mono text-zinc-700">
                    <.link navigate={~p"/queries/#{query.query_id}"} class="hover:text-blue-600">
                      <%= truncate_query(query.query_text) %>
                    </.link>
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                    <%= format_time(query.total_exec_time) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                    <%= format_time(query.mean_exec_time) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                    <%= format_number(query.calls) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                    <%= format_number(query.rows) %>
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                    <%= cache_hit_ratio(query) %>%
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @queries == [] do %>
            <div class="px-6 py-12 text-center text-zinc-500">
              No query data yet. Waiting for first snapshot...
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp truncate_query(nil), do: "(unknown)"
  defp truncate_query(q) when byte_size(q) > 100, do: String.slice(q, 0, 100) <> "..."
  defp truncate_query(q), do: q

  defp format_time(nil), do: "-"
  defp format_time(ms) when ms >= 1_000, do: "#{Float.round(ms / 1_000, 2)}s"
  defp format_time(ms), do: "#{Float.round(ms * 1.0, 2)}ms"

  defp format_number(nil), do: "-"
  defp format_number(n) when is_integer(n) and n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: to_string(n)

  defp cache_hit_ratio(query) do
    hit = query.shared_blks_hit || 0
    read = query.shared_blks_read || 0
    total = hit + read
    if total > 0, do: Float.round(hit / total * 100, 1), else: 0.0
  end

  defp sort_indicator(field, current_field, dir) do
    if field == current_field do
      if dir == "desc", do: raw("&darr;"), else: raw("&uarr;")
    else
      ""
    end
  end
end
