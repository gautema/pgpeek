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
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-white">All Queries</h1>
            <p class="mt-1 text-sm text-slate-400">
              <%= if @snapshot do %>
                Snapshot from <%= Calendar.strftime(@snapshot.captured_at, "%Y-%m-%d %H:%M:%S UTC") %>
                &middot; <%= length(@queries) %> queries
              <% else %>
                Waiting for first snapshot...
              <% end %>
            </p>
          </div>
        </div>

        <div class="glass-card overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="border-b border-white/5">
                  <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500">
                    Query
                  </th>
                  <.sort_header field="total_exec_time" label="Total Time" current={@sort_by} dir={@sort_dir} />
                  <.sort_header field="mean_exec_time" label="Mean Time" current={@sort_by} dir={@sort_dir} />
                  <.sort_header field="calls" label="Calls" current={@sort_by} dir={@sort_dir} />
                  <.sort_header field="rows" label="Rows" current={@sort_by} dir={@sort_dir} />
                  <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500 hidden lg:table-cell">
                    Cache Hit %
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <%= for query <- @queries do %>
                  <tr class="group hover:bg-white/[0.02] transition-colors">
                    <td class="max-w-lg truncate px-6 py-3 text-sm font-mono text-slate-300">
                      <.link navigate={~p"/queries/#{query.query_id}"} class="hover:text-blue-400 transition-colors">
                        <%= truncate_query(query.query_text) %>
                      </.link>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-300">
                      <%= format_time(query.total_exec_time) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                      <%= format_time(query.mean_exec_time) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                      <%= format_number(query.calls) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                      <%= format_number(query.rows) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums hidden lg:table-cell">
                      <.cache_badge ratio={cache_hit_ratio(query)} />
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @queries == [] do %>
              <div class="px-6 py-16 text-center">
                <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-white/5 mb-3">
                  <.icon name="hero-command-line" class="size-5 text-slate-500" />
                </div>
                <p class="text-sm text-slate-500">No query data yet. Waiting for first snapshot...</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :current, :string, required: true
  attr :dir, :string, required: true

  defp sort_header(assigns) do
    ~H"""
    <th
      class="cursor-pointer px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500 hover:text-slate-300 transition-colors select-none"
      phx-click="sort"
      phx-value-field={@field}
    >
      <span class="inline-flex items-center gap-1">
        {@label}
        <%= if @field == @current do %>
          <%= if @dir == "desc" do %>
            <.icon name="hero-chevron-down-micro" class="size-3 text-blue-400" />
          <% else %>
            <.icon name="hero-chevron-up-micro" class="size-3 text-blue-400" />
          <% end %>
        <% end %>
      </span>
    </th>
    """
  end

  attr :ratio, :float, required: true

  defp cache_badge(assigns) do
    color =
      cond do
        assigns.ratio >= 99.0 -> "text-emerald-400"
        assigns.ratio >= 95.0 -> "text-blue-400"
        assigns.ratio >= 90.0 -> "text-amber-400"
        true -> "text-red-400"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={@color}><%= @ratio %>%</span>
    """
  end

  defp truncate_query(nil), do: "(unknown)"
  defp truncate_query(q) when byte_size(q) > 90, do: String.slice(q, 0, 90) <> "..."
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
end
