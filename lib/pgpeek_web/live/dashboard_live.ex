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

    {top_queries, deltas, n_plus_ones, regressions} =
      if snapshot do
        stats = Snapshots.top_queries_by_total_time(snapshot.id, 10)
        all_stats = Snapshots.query_stats_for_snapshot(snapshot.id)
        prev = Snapshots.get_previous_snapshot(snapshot)

        {deltas, all_deltas, period_minutes} =
          if prev do
            prev_stats = Snapshots.query_stats_for_snapshot(prev.id)
            top_deltas = Snapshots.compute_deltas(stats, prev_stats)
            full_deltas = Snapshots.compute_deltas(all_stats, prev_stats)

            period =
              DateTime.diff(snapshot.captured_at, prev.captured_at, :second) / 60.0

            {top_deltas, full_deltas, period}
          else
            top_deltas =
              Enum.map(stats, fn s ->
                %{stat: s, delta_calls: s.calls || 0, delta_total_time: s.total_exec_time || 0, delta_mean_time: s.mean_exec_time || 0, new: true}
              end)

            {top_deltas, top_deltas, 0}
          end

        n_plus_ones = Snapshots.detect_n_plus_one(all_deltas, period_minutes)
        regressions = Snapshots.detect_regressions(all_stats)

        {stats, deltas, n_plus_ones, regressions}
      else
        {[], [], [], []}
      end

    {db_stats, connections} = load_pg_stats()

    socket
    |> assign(:snapshot, snapshot)
    |> assign(:top_queries, top_queries)
    |> assign(:deltas, deltas)
    |> assign(:n_plus_ones, n_plus_ones)
    |> assign(:regressions, regressions)
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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-white">Dashboard</h1>
            <p class="mt-1 text-sm text-slate-400">Postgres performance at a glance</p>
          </div>
          <%= if @snapshot do %>
            <div class="flex items-center gap-2 text-xs text-slate-500">
              <.icon name="hero-clock" class="size-3.5" />
              <span>Last snapshot: <%= Calendar.strftime(@snapshot.captured_at, "%Y-%m-%d %H:%M:%S UTC") %></span>
            </div>
          <% end %>
        </div>

        <%= if not @configured do %>
          <div class="glass-card p-8 text-center">
            <div class="mx-auto flex items-center justify-center size-12 rounded-full bg-amber-500/10 mb-4">
              <.icon name="hero-exclamation-triangle" class="size-6 text-amber-400" />
            </div>
            <h2 class="text-lg font-semibold text-white">No database configured</h2>
            <p class="mt-2 text-sm text-slate-400 max-w-md mx-auto">
              Set the <code class="px-1.5 py-0.5 rounded bg-white/5 text-amber-300 font-mono text-xs">DATABASE_URL</code>
              environment variable to connect to your Postgres database.
            </p>
          </div>
        <% end %>

        <%= if @configured or @snapshot do %>
          <%!-- Stat Cards --%>
          <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <.stat_card
              title="Cache Hit Ratio"
              value={"#{@db_stats.cache_hit_ratio}%"}
              icon="hero-bolt"
              color="emerald"
              subtitle="Block reads from cache"
            />
            <.stat_card
              title="Connections"
              value={@connections |> Map.values() |> Enum.sum() |> to_string()}
              icon="hero-signal"
              color="blue"
              subtitle={connection_summary(@connections)}
            />
            <.stat_card
              title="Tracked Queries"
              value={length(@top_queries) |> to_string()}
              icon="hero-command-line"
              color="violet"
              subtitle="In latest snapshot"
            />
            <.stat_card
              title="Snapshots"
              value={if @snapshot, do: to_string(@snapshot.id), else: "0"}
              icon="hero-camera"
              color="amber"
              subtitle="Total captured"
            />
          </div>

          <%!-- Anomalies --%>
          <%= if @n_plus_ones != [] or @regressions != [] do %>
            <div class="space-y-4">
              <%= for item <- @regressions do %>
                <.anomaly_card
                  kind="regression"
                  query_id={item.query_id}
                  query_text={item.query_text}
                  detail={"Mean time #{format_time(item.mean_exec_time)} is more than 2x the 7-day baseline (#{format_number(item.calls)} calls)"}
                />
              <% end %>
              <%= for item <- @n_plus_ones do %>
                <.anomaly_card
                  kind="n+1"
                  query_id={item.stat.query_id}
                  query_text={item.stat.query_text}
                  detail={"#{format_number(item.delta_calls)} calls in the last period (mean #{format_time(item.stat.mean_exec_time)})"}
                />
              <% end %>
            </div>
          <% end %>

          <%!-- Top Queries Table --%>
          <div class="glass-card overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-white/5">
              <div class="flex items-center gap-2">
                <.icon name="hero-fire" class="size-5 text-orange-400" />
                <h2 class="text-base font-semibold text-white">Top Queries by Total Time</h2>
              </div>
              <.link navigate={~p"/queries"} class="text-xs font-medium text-blue-400 hover:text-blue-300 transition-colors">
                View all &rarr;
              </.link>
            </div>
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="border-b border-white/5">
                    <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500">Query</th>
                    <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Total Time</th>
                    <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Mean</th>
                    <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Calls</th>
                    <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500 hidden sm:table-cell">Delta</th>
                    <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500 hidden md:table-cell">Rows</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/5">
                  <%= for delta <- @deltas do %>
                    <tr class="group hover:bg-white/[0.02] transition-colors">
                      <td class="max-w-xs truncate px-6 py-3 text-sm font-mono text-slate-300">
                        <.link navigate={~p"/queries/#{delta.stat.query_id}"} class="hover:text-blue-400 transition-colors">
                          <%= truncate_query(delta.stat.query_text) %>
                        </.link>
                      </td>
                      <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-300">
                        <%= format_time(delta.stat.total_exec_time) %>
                      </td>
                      <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                        <%= format_time(delta.stat.mean_exec_time) %>
                      </td>
                      <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                        <%= format_number(delta.stat.calls) %>
                      </td>
                      <td class={"whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums hidden sm:table-cell #{delta_color(delta.delta_calls)}"}>
                        <%= if delta.delta_calls > 0 do %>
                          <span class="inline-flex items-center gap-0.5">
                            <.icon name="hero-arrow-up-micro" class="size-3" />
                            <%= format_number(delta.delta_calls) %>
                          </span>
                        <% else %>
                          <%= format_number(delta.delta_calls) %>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400 hidden md:table-cell">
                        <%= format_number(delta.stat.rows) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
              <%= if @deltas == [] do %>
                <div class="px-6 py-16 text-center">
                  <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-white/5 mb-3">
                    <.icon name="hero-clock" class="size-5 text-slate-500" />
                  </div>
                  <p class="text-sm text-slate-500">No query data yet. Waiting for first snapshot...</p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :subtitle, :string, default: nil

  defp stat_card(assigns) do
    color_classes = %{
      "emerald" => "bg-emerald-500/10 text-emerald-400",
      "blue" => "bg-blue-500/10 text-blue-400",
      "violet" => "bg-violet-500/10 text-violet-400",
      "amber" => "bg-amber-500/10 text-amber-400"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, "bg-white/10 text-white"))

    ~H"""
    <div class="glass-card p-5">
      <div class="flex items-center gap-3 mb-3">
        <div class={"flex items-center justify-center size-8 rounded-lg #{@color_class}"}>
          <.icon name={@icon} class="size-4" />
        </div>
        <p class="text-xs font-medium uppercase tracking-wider text-slate-500">{@title}</p>
      </div>
      <p class="text-2xl font-bold text-white tabular-nums">{@value}</p>
      <%= if @subtitle do %>
        <p class="mt-1 text-xs text-slate-500">{@subtitle}</p>
      <% end %>
    </div>
    """
  end

  attr :kind, :string, required: true
  attr :query_id, :string, required: true
  attr :query_text, :string, default: nil
  attr :detail, :string, required: true

  defp anomaly_card(assigns) do
    {icon, color, label} =
      case assigns.kind do
        "regression" -> {"hero-arrow-trending-up", "red", "Regression"}
        "n+1" -> {"hero-arrow-path-rounded-square", "amber", "Suspected N+1"}
        _ -> {"hero-exclamation-triangle", "amber", "Anomaly"}
      end

    color_classes = %{
      "red" => %{bg: "bg-red-500/10", border: "border-red-500/20", icon: "text-red-400", badge: "bg-red-500/10 text-red-400"},
      "amber" => %{bg: "bg-amber-500/10", border: "border-amber-500/20", icon: "text-amber-400", badge: "bg-amber-500/10 text-amber-400"}
    }

    c = Map.get(color_classes, color)

    assigns =
      assigns
      |> assign(:icon, icon)
      |> assign(:label, label)
      |> assign(:c, c)

    ~H"""
    <div class={"glass-card #{@c.border} border overflow-hidden"}>
      <div class="flex items-start gap-4 px-5 py-4">
        <div class={"flex items-center justify-center size-9 rounded-lg shrink-0 #{@c.bg}"}>
          <.icon name={@icon} class={"size-5 #{@c.icon}"} />
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2 mb-1">
            <span class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold #{@c.badge}"}>
              {@label}
            </span>
          </div>
          <.link navigate={~p"/queries/#{@query_id}"} class="block text-sm font-mono text-slate-300 truncate hover:text-blue-400 transition-colors">
            <%= truncate_query(@query_text) %>
          </.link>
          <p class="mt-1 text-xs text-slate-500">{@detail}</p>
        </div>
      </div>
    </div>
    """
  end

  defp truncate_query(nil), do: "(unknown)"
  defp truncate_query(q) when byte_size(q) > 70, do: String.slice(q, 0, 70) <> "..."
  defp truncate_query(q), do: q

  defp format_time(nil), do: "-"
  defp format_time(ms) when ms >= 1_000, do: "#{Float.round(ms / 1_000, 2)}s"
  defp format_time(ms), do: "#{Float.round(ms * 1.0, 2)}ms"

  defp format_number(nil), do: "-"
  defp format_number(n) when is_integer(n) and n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: to_string(n)

  defp delta_color(n) when n > 0, do: "text-amber-400"
  defp delta_color(_), do: "text-slate-500"

  defp connection_summary(connections) do
    active = Map.get(connections, "active", 0)
    idle = Map.get(connections, "idle", 0)
    "#{active} active, #{idle} idle"
  end
end
