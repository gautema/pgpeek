defmodule PgpeekWeb.DiagnoseLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Diagnostics
  alias Pgpeek.ProbeRepo

  @categories [
    {"health", "Health", "hero-heart", [
      {"cache_hit", "Cache Hit Ratio"},
      {"table_cache_hit", "Table Cache Hit"},
      {"index_cache_hit", "Index Cache Hit"}
    ]},
    {"indexes", "Indexes", "hero-list-bullet", [
      {"missing_fk_indexes", "Missing FK Indexes"},
      {"unused_indexes", "Unused Indexes"},
      {"duplicate_indexes", "Duplicate Indexes"},
      {"null_indexes", "Null Indexes"},
      {"index_usage", "Index Usage"},
      {"index_sizes", "Index Sizes"}
    ]},
    {"tables", "Tables", "hero-table-cells", [
      {"table_sizes", "Table Sizes"},
      {"vacuum_stats", "Vacuum Stats"},
      {"seq_scans", "Sequential Scans"},
      {"records_rank", "Records Rank"}
    ]},
    {"queries", "Queries", "hero-command-line", [
      {"long_running", "Long Running Queries"},
      {"outliers", "Outliers"},
      {"by_calls", "Calls"}
    ]},
    {"connections", "Connections", "hero-signal", [
      {"connection_summary", "Summary"},
      {"current_connections", "Connections"},
      {"locks", "Waiting Locks"},
      {"blocking", "Blocking Queries"},
      {"all_locks", "All Locks"}
    ]},
    {"system", "System", "hero-cog-6-tooth", [
      {"db_settings", "DB Settings"},
      {"extensions", "Extensions"},
      {"database_size", "Database Size"},
      {"missing_fk_constraints", "Missing FK Constraints"}
    ]}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Diagnose")
      |> assign(:categories, @categories)
      |> assign(:active_check, nil)
      |> assign(:results, nil)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:configured, ProbeRepo.configured?())

    {:ok, socket}
  end

  @impl true
  def handle_event("run_check", %{"check" => check}, socket) do
    if not socket.assigns.configured do
      {:noreply, assign(socket, :error, "No database configured")}
    else
      socket =
        socket
        |> assign(:active_check, check)
        |> assign(:loading, true)
        |> assign(:results, nil)
        |> assign(:error, nil)

      send(self(), {:run_check, check})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:run_check, check}, socket) do
    {results, error} = run_diagnostic(check)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:results, results)
      |> assign(:error, error)

    {:noreply, socket}
  end

  defp run_diagnostic(check) do
    result =
      case check do
        "cache_hit" -> Diagnostics.cache_hit_ratio()
        "table_cache_hit" -> Diagnostics.table_cache_hit()
        "index_cache_hit" -> Diagnostics.index_cache_hit()
        "missing_fk_indexes" -> Diagnostics.missing_fk_indexes()
        "unused_indexes" -> Diagnostics.unused_indexes()
        "duplicate_indexes" -> Diagnostics.duplicate_indexes()
        "null_indexes" -> Diagnostics.null_indexes()
        "index_usage" -> Diagnostics.index_usage()
        "index_sizes" -> Diagnostics.index_sizes()
        "table_sizes" -> Diagnostics.table_sizes()
        "vacuum_stats" -> Diagnostics.vacuum_stats()
        "seq_scans" -> Diagnostics.seq_scans()
        "records_rank" -> Diagnostics.records_rank()
        "long_running" -> Diagnostics.long_running_queries(5)
        "outliers" -> Diagnostics.query_outliers()
        "by_calls" -> Diagnostics.query_calls()
        "connection_summary" -> Diagnostics.connection_summary()
        "current_connections" -> Diagnostics.current_connections()
        "locks" -> Diagnostics.locks()
        "blocking" -> Diagnostics.blocking_queries()
        "all_locks" -> Diagnostics.all_locks()
        "db_settings" -> Diagnostics.db_settings()
        "extensions" -> Diagnostics.extensions()
        "database_size" -> Diagnostics.database_size()
        "missing_fk_constraints" -> Diagnostics.missing_fk_constraints()
        _ -> {:error, "Unknown check"}
      end

    case result do
      {:ok, rows} -> {rows, nil}
      {:error, %Postgrex.Error{postgres: %{message: msg}}} -> {nil, msg}
      {:error, reason} -> {nil, inspect(reason)}
    end
  end

  defp check_label(check_id) do
    Enum.find_value(@categories, check_id, fn {_id, _name, _icon, checks} ->
      Enum.find_value(checks, fn {id, label} ->
        if id == check_id, do: label
      end)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div>
          <h1 class="text-2xl font-bold text-white">Diagnose</h1>
          <p class="mt-1 text-sm text-slate-400">Run diagnostic checks against your database</p>
        </div>

        <%= if not @configured do %>
          <div class="glass-card p-8 text-center">
            <div class="mx-auto flex items-center justify-center size-12 rounded-full bg-amber-500/10 mb-4">
              <.icon name="hero-exclamation-triangle" class="size-6 text-amber-400" />
            </div>
            <h2 class="text-lg font-semibold text-white">No database configured</h2>
            <p class="mt-2 text-sm text-slate-400">
              Set <code class="px-1.5 py-0.5 rounded bg-white/5 text-amber-300 font-mono text-xs">DATABASE_URL</code> to run diagnostics.
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 gap-6 lg:grid-cols-4">
            <%!-- Sidebar --%>
            <div class="lg:col-span-1 space-y-2">
              <%= for {_cat_id, cat_name, cat_icon, checks} <- @categories do %>
                <div class="glass-card overflow-hidden">
                  <div class="flex items-center gap-2 px-4 py-2.5 border-b border-white/5">
                    <.icon name={cat_icon} class="size-4 text-slate-500" />
                    <span class="text-xs font-semibold uppercase tracking-wider text-slate-500">{cat_name}</span>
                  </div>
                  <div class="py-1">
                    <%= for {check_id, check_label} <- checks do %>
                      <button
                        phx-click="run_check"
                        phx-value-check={check_id}
                        class={[
                          "w-full text-left px-4 py-2 text-sm transition-colors cursor-pointer",
                          if(@active_check == check_id,
                            do: "bg-blue-500/10 text-blue-400",
                            else: "text-slate-400 hover:text-white hover:bg-white/5"
                          )
                        ]}
                      >
                        {check_label}
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <%!-- Results Panel --%>
            <div class="lg:col-span-3">
              <%= cond do %>
                <% @loading -> %>
                  <div class="glass-card p-16 text-center">
                    <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-blue-500/10 mb-3">
                      <.icon name="hero-arrow-path" class="size-5 text-blue-400 animate-spin" />
                    </div>
                    <p class="text-sm text-slate-400">Running diagnostic...</p>
                  </div>

                <% @error -> %>
                  <div class="glass-card p-8 text-center">
                    <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-red-500/10 mb-3">
                      <.icon name="hero-x-circle" class="size-5 text-red-400" />
                    </div>
                    <p class="text-sm text-red-400">{@error}</p>
                  </div>

                <% @results != nil -> %>
                  <div class="glass-card overflow-hidden">
                    <div class="flex items-center justify-between px-6 py-4 border-b border-white/5">
                      <h2 class="text-base font-semibold text-white">{check_label(@active_check)}</h2>
                      <span class="text-xs text-slate-500"><%= length(@results) %> results</span>
                    </div>
                    <%= if @results == [] do %>
                      <div class="px-6 py-16 text-center">
                        <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-emerald-500/10 mb-3">
                          <.icon name="hero-check-circle" class="size-5 text-emerald-400" />
                        </div>
                        <p class="text-sm text-emerald-400">All clear — nothing to report.</p>
                      </div>
                    <% else %>
                      <div class="overflow-x-auto">
                        <.result_table rows={@results} />
                      </div>
                    <% end %>
                  </div>

                <% true -> %>
                  <div class="glass-card p-16 text-center">
                    <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-white/5 mb-3">
                      <.icon name="hero-cursor-arrow-rays" class="size-5 text-slate-500" />
                    </div>
                    <p class="text-sm text-slate-500">Select a diagnostic check from the sidebar</p>
                  </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp result_table(assigns) do
    columns =
      case assigns.rows do
        [first | _] -> Map.keys(first) |> Enum.sort()
        [] -> []
      end

    assigns = assign(assigns, :columns, columns)

    ~H"""
    <table class="w-full">
      <thead>
        <tr class="border-b border-white/5">
          <%= for col <- @columns do %>
            <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500 whitespace-nowrap">
              {col}
            </th>
          <% end %>
        </tr>
      </thead>
      <tbody class="divide-y divide-white/5">
        <%= for row <- @rows do %>
          <tr class="hover:bg-white/[0.02] transition-colors">
            <%= for col <- @columns do %>
              <td class="px-4 py-2.5 text-sm text-slate-300 max-w-xs truncate font-mono">
                {format_cell(Map.get(row, col))}
              </td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp format_cell(nil), do: "-"
  defp format_cell(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_cell(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_cell(val) when is_float(val), do: Float.round(val, 2) |> to_string()
  defp format_cell(val) when is_boolean(val), do: to_string(val)
  defp format_cell(%Decimal{} = val), do: Decimal.to_string(val)

  defp format_cell(%Postgrex.Interval{} = interval) do
    total_secs = interval.secs + interval.days * 86400 + interval.months * 2_592_000

    cond do
      total_secs >= 3600 -> "#{div(total_secs, 3600)}h #{rem(div(total_secs, 60), 60)}m"
      total_secs >= 60 -> "#{div(total_secs, 60)}m #{rem(total_secs, 60)}s"
      true -> "#{total_secs}s"
    end
  end

  defp format_cell(val) when is_binary(val) and byte_size(val) > 200 do
    String.slice(val, 0, 200) <> "..."
  end

  defp format_cell(val), do: to_string(val)
end
