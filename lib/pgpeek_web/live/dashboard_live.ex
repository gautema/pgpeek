defmodule PgpeekWeb.DashboardLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Snapshots
  alias Pgpeek.ProbeRepo

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pgpeek.PubSub, "snapshots")
    end

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_snapshot, _snapshot_id}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  defp load_dashboard_data(socket) do
    snapshot = Snapshots.get_latest_snapshot()

    {top_queries, deltas} =
      if snapshot do
        stats = Snapshots.top_queries_by_total_time(snapshot.id, 10)
        prev = Snapshots.get_previous_snapshot(snapshot)

        deltas =
          if prev do
            prev_stats = Snapshots.query_stats_for_snapshot(prev.id)
            Snapshots.compute_deltas(stats, prev_stats)
          else
            Enum.map(stats, fn s ->
              %{stat: s, delta_calls: s.calls || 0, delta_total_time: s.total_exec_time || 0, delta_mean_time: s.mean_exec_time || 0, new: true}
            end)
          end

        {stats, deltas}
      else
        {[], []}
      end

    {db_stats, connections} = load_pg_stats()

    socket
    |> assign(:snapshot, snapshot)
    |> assign(:top_queries, top_queries)
    |> assign(:deltas, deltas)
    |> assign(:db_stats, db_stats)
    |> assign(:connections, connections)
    |> assign(:configured, ProbeRepo.configured?())
  end

  defp load_pg_stats do
    if ProbeRepo.configured?() do
      db_stats =
        case ProbeRepo.query("SELECT blks_hit, blks_read FROM pg_stat_database WHERE datname = current_database()") do
          {:ok, %{rows: [[hit, read]]}} ->
            total = (hit || 0) + (read || 0)
            ratio = if total > 0, do: Float.round(hit / total * 100, 2), else: 0.0
            %{cache_hit_ratio: ratio, blks_hit: hit, blks_read: read}

          _ ->
            %{cache_hit_ratio: 0.0, blks_hit: 0, blks_read: 0}
        end

      connections =
        case ProbeRepo.query("SELECT state, count(*) FROM pg_stat_activity GROUP BY state") do
          {:ok, %{rows: rows}} -> Map.new(rows, fn [state, count] -> {state || "null", count} end)
          _ -> %{}
        end

      {db_stats, connections}
    else
      {%{cache_hit_ratio: 0.0, blks_hit: 0, blks_read: 0}, %{}}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold text-zinc-900">Dashboard</h1>
        <%= if @snapshot do %>
          <p class="text-sm text-zinc-500">
            Last snapshot: <%= Calendar.strftime(@snapshot.captured_at, "%Y-%m-%d %H:%M:%S UTC") %>
          </p>
        <% end %>
      </div>

      <%= if not @configured do %>
        <div class="rounded-lg border border-amber-200 bg-amber-50 p-6">
          <h2 class="text-lg font-semibold text-amber-800">No database configured</h2>
          <p class="mt-2 text-amber-700">
            Set the <code class="bg-amber-100 px-1 rounded">DATABASE_URL</code> environment variable to connect to your Postgres database.
          </p>
        </div>
      <% else %>
        <!-- Stats Cards -->
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card title="Cache Hit Ratio" value={"#{@db_stats.cache_hit_ratio}%"} subtitle="Block reads from cache" />
          <.stat_card
            title="Connections"
            value={@connections |> Map.values() |> Enum.sum() |> to_string()}
            subtitle={connection_summary(@connections)}
          />
          <.stat_card
            title="Tracked Queries"
            value={length(@top_queries) |> to_string()}
            subtitle="In latest snapshot"
          />
          <.stat_card
            title="Snapshots"
            value={if @snapshot, do: to_string(@snapshot.id), else: "0"}
            subtitle="Total captured"
          />
        </div>

        <!-- Top Queries -->
        <div class="rounded-lg border border-zinc-200 bg-white">
          <div class="border-b border-zinc-200 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Top Queries by Total Time</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-200">
              <thead class="bg-zinc-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Query</th>
                  <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Total Time</th>
                  <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Mean Time</th>
                  <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Calls</th>
                  <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Δ Calls</th>
                  <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">Rows</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-200 bg-white">
                <%= for delta <- @deltas do %>
                  <tr class="hover:bg-zinc-50">
                    <td class="max-w-md truncate px-6 py-4 text-sm font-mono text-zinc-700">
                      <.link navigate={~p"/queries/#{delta.stat.query_id}"} class="hover:text-blue-600">
                        <%= truncate_query(delta.stat.query_text) %>
                      </.link>
                    </td>
                    <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                      <%= format_time(delta.stat.total_exec_time) %>
                    </td>
                    <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                      <%= format_time(delta.stat.mean_exec_time) %>
                    </td>
                    <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                      <%= format_number(delta.stat.calls) %>
                    </td>
                    <td class={"whitespace-nowrap px-6 py-4 text-right text-sm #{delta_color(delta.delta_calls)}"}>
                      <%= if delta.delta_calls > 0, do: "+", else: "" %><%= format_number(delta.delta_calls) %>
                    </td>
                    <td class="whitespace-nowrap px-6 py-4 text-right text-sm text-zinc-700">
                      <%= format_number(delta.stat.rows) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @deltas == [] do %>
              <div class="px-6 py-12 text-center text-zinc-500">
                No query data yet. Waiting for first snapshot...
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-6">
      <p class="text-sm font-medium text-zinc-500"><%= @title %></p>
      <p class="mt-2 text-3xl font-bold text-zinc-900"><%= @value %></p>
      <p class="mt-1 text-sm text-zinc-500"><%= @subtitle %></p>
    </div>
    """
  end

  defp truncate_query(nil), do: "(unknown)"
  defp truncate_query(q) when byte_size(q) > 80, do: String.slice(q, 0, 80) <> "..."
  defp truncate_query(q), do: q

  defp format_time(nil), do: "—"
  defp format_time(ms) when ms >= 1_000, do: "#{Float.round(ms / 1_000, 2)}s"
  defp format_time(ms), do: "#{Float.round(ms * 1.0, 2)}ms"

  defp format_number(nil), do: "—"
  defp format_number(n) when is_integer(n) and n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: to_string(n)

  defp delta_color(n) when n > 0, do: "text-amber-600"
  defp delta_color(_), do: "text-zinc-500"

  defp connection_summary(connections) do
    active = Map.get(connections, "active", 0)
    idle = Map.get(connections, "idle", 0)
    "#{active} active, #{idle} idle"
  end
end
