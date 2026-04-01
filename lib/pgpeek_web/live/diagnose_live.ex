defmodule PgpeekWeb.DiagnoseLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Diagnostics
  alias Pgpeek.ProbeRepo

  @checks %{
    "cache_hit" => %{
      label: "Cache Hit Ratio",
      desc: "Percentage of database reads served from shared buffer cache vs disk. Below 99% on production usually means shared_buffers is too small."
    },
    "table_cache_hit" => %{
      label: "Table Cache Hit",
      desc: "Per-table heap block cache hit ratio. Tables with low ratios are being read from disk frequently — consider increasing shared_buffers or optimizing queries."
    },
    "index_cache_hit" => %{
      label: "Index Cache Hit",
      desc: "Per-index block cache hit ratio. Indexes with low ratios cause slow lookups as pages are fetched from disk instead of memory."
    },
    "missing_fk_indexes" => %{
      label: "Missing FK Indexes",
      desc: "Foreign key columns without a supporting index. These cause slow cascading deletes and expensive joins. Adding an index is almost always the right fix."
    },
    "unused_indexes" => %{
      label: "Unused Indexes",
      desc: "Non-unique indexes with zero scans since the last stats reset. Each unused index slows down writes and wastes disk space. Safe to drop if stats have been accumulating for a representative period."
    },
    "duplicate_indexes" => %{
      label: "Duplicate Indexes",
      desc: "Indexes covering the same columns in the same order on the same table. Only one is needed — the rest waste space and slow writes."
    },
    "null_indexes" => %{
      label: "Null Indexes",
      desc: "Single-column indexes on nullable columns without a partial index condition. If most rows are NULL, a partial index with WHERE column IS NOT NULL would be much smaller."
    },
    "index_usage" => %{
      label: "Index Usage",
      desc: "Ratio of index scans to sequential scans per table. Tables with low index usage and many rows may be missing indexes, or queries aren't using existing ones."
    },
    "index_sizes" => %{
      label: "Index Sizes",
      desc: "All indexes sorted by size on disk. Large indexes that are rarely scanned are candidates for removal or restructuring."
    },
    "table_sizes" => %{
      label: "Table Sizes",
      desc: "Total disk footprint per table including heap, toast, and all indexes. Helps identify the largest consumers of storage."
    },
    "vacuum_stats" => %{
      label: "Vacuum Stats",
      desc: "Dead tuple counts and last vacuum/analyze timestamps. High dead tuple ratios indicate autovacuum is falling behind — rows can't be reclaimed until vacuumed."
    },
    "seq_scans" => %{
      label: "Sequential Scans",
      desc: "Tables with the most sequential (full table) scans. Frequent seq scans on large tables usually means a missing index. Small tables are fine."
    },
    "records_rank" => %{
      label: "Records Rank",
      desc: "Tables ranked by estimated live row count. Useful for understanding data distribution and identifying unexpectedly large tables."
    },
    "long_running" => %{
      label: "Long Running Queries",
      desc: "Currently executing queries running longer than 5 seconds. Long-running queries hold locks and consume resources. Check for missing indexes or inefficient plans."
    },
    "outliers" => %{
      label: "Outliers",
      desc: "Queries ranked by total execution time from pg_stat_statements. These are the queries consuming the most database time overall — the best optimization targets."
    },
    "by_calls" => %{
      label: "Calls",
      desc: "Queries ranked by call frequency. High-frequency queries with even small improvements yield large cumulative gains."
    },
    "connection_summary" => %{
      label: "Summary",
      desc: "Connection counts vs max_connections limit. Approaching the limit causes connection refused errors. Idle-in-transaction connections hold locks and block autovacuum."
    },
    "current_connections" => %{
      label: "Connections",
      desc: "Active connections grouped by user, application, and state. Helps identify which application or service is consuming the most connections."
    },
    "locks" => %{
      label: "Waiting Locks",
      desc: "Lock requests that have not yet been granted. Queries waiting on locks are blocked and cannot proceed until the holder releases. Investigate the blocking query."
    },
    "blocking" => %{
      label: "Blocking Queries",
      desc: "Queries that are actively blocking other queries from proceeding. Shows both the blocker and the blocked query so you can decide which to cancel."
    },
    "all_locks" => %{
      label: "All Locks",
      desc: "Every lock currently held or awaited in the database. Useful for understanding the full locking picture during complex debugging."
    },
    "db_settings" => %{
      label: "DB Settings",
      desc: "Key performance-related PostgreSQL configuration parameters. Compare against recommended values for your workload and hardware."
    },
    "extensions" => %{
      label: "Extensions",
      desc: "Installed PostgreSQL extensions. pg_stat_statements is required for PgPeek query tracking. Other useful extensions include pg_trgm, btree_gist, and pgcrypto."
    },
    "database_size" => %{
      label: "Database Size",
      desc: "Total on-disk size of the current database including all tables, indexes, and toast data."
    },
    "missing_fk_constraints" => %{
      label: "Missing FK Constraints",
      desc: "Columns ending in _id that have no foreign key constraint. This is a heuristic — some may be intentional (polymorphic IDs, external references) but many are oversights."
    }
  }

  @categories [
    {"health", "Health", "hero-heart",
     ["cache_hit", "table_cache_hit", "index_cache_hit"]},
    {"indexes", "Indexes", "hero-list-bullet",
     ["missing_fk_indexes", "unused_indexes", "duplicate_indexes", "null_indexes", "index_usage", "index_sizes"]},
    {"tables", "Tables", "hero-table-cells",
     ["table_sizes", "vacuum_stats", "seq_scans", "records_rank"]},
    {"queries", "Queries", "hero-command-line",
     ["long_running", "outliers", "by_calls"]},
    {"connections", "Connections", "hero-signal",
     ["connection_summary", "current_connections", "locks", "blocking", "all_locks"]},
    {"system", "System", "hero-cog-6-tooth",
     ["db_settings", "extensions", "database_size", "missing_fk_constraints"]}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Diagnose")
      |> assign(:categories, @categories)
      |> assign(:checks, @checks)
      |> assign(:active_check, nil)
      |> assign(:results, nil)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:configured, ProbeRepo.configured?())
      |> assign(:ai_advice, nil)
      |> assign(:ai_loading, false)
      |> assign(:ai_error, nil)
      |> assign(:llm_configured, Pgpeek.QueryExplainer.configured?())

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
        |> assign(:ai_advice, nil)
        |> assign(:ai_error, nil)

      send(self(), {:run_check, check})
      {:noreply, socket}
    end
  end

  def handle_event("ai_advise", _params, socket) do
    socket = assign(socket, :ai_loading, true)
    send(self(), :run_ai_advise)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:run_ai_advise, socket) do
    check = get_check(socket.assigns.active_check)

    {advice, error} =
      case Pgpeek.QueryExplainer.advise_diagnostic(check.label, check.desc, socket.assigns.results || []) do
        {:ok, text} -> {text, nil}
        {:error, msg} -> {nil, to_string(msg)}
      end

    socket =
      socket
      |> assign(:ai_advice, advice)
      |> assign(:ai_error, error)
      |> assign(:ai_loading, false)

    {:noreply, socket}
  end

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

  defp get_check(check_id), do: Map.get(@checks, check_id, %{label: check_id, desc: ""})

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
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
              <%= for {_cat_id, cat_name, cat_icon, check_ids} <- @categories do %>
                <div class="glass-card overflow-hidden">
                  <div class="flex items-center gap-2 px-4 py-2.5 border-b border-white/5">
                    <.icon name={cat_icon} class="size-4 text-slate-500" />
                    <span class="text-xs font-semibold uppercase tracking-wider text-slate-500">{cat_name}</span>
                  </div>
                  <div class="py-1">
                    <%= for check_id <- check_ids do %>
                      <% check = get_check(check_id) %>
                      <button
                        phx-click="run_check"
                        phx-value-check={check_id}
                        title={check.desc}
                        class={[
                          "w-full text-left px-4 py-2 text-sm transition-colors cursor-pointer",
                          if(@active_check == check_id,
                            do: "bg-blue-500/10 text-blue-400",
                            else: "text-slate-400 hover:text-white hover:bg-white/5"
                          )
                        ]}
                      >
                        {check.label}
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
                  <% check = get_check(@active_check) %>
                  <div class="glass-card overflow-hidden">
                    <div class="px-6 py-4 border-b border-white/5">
                      <div class="flex items-center justify-between">
                        <h2 class="text-base font-semibold text-white">{check.label}</h2>
                        <div class="flex items-center gap-3">
                          <%= if @llm_configured and @results != [] do %>
                            <button
                              phx-click="ai_advise"
                              disabled={@ai_loading}
                              class={[
                                "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors",
                                if(@ai_loading,
                                  do: "bg-white/5 text-slate-500 cursor-wait",
                                  else: "bg-violet-500/10 text-violet-400 hover:bg-violet-500/20 cursor-pointer"
                                )
                              ]}
                            >
                              <%= if @ai_loading do %>
                                <.icon name="hero-arrow-path" class="size-3.5 animate-spin" />
                                Thinking...
                              <% else %>
                                <.icon name="hero-sparkles" class="size-3.5" />
                                What should I do?
                              <% end %>
                            </button>
                          <% end %>
                          <span class="text-xs text-slate-500"><%= length(@results) %> results</span>
                        </div>
                      </div>
                      <p class="mt-1 text-sm text-slate-500">{check.desc}</p>
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

                  <%!-- AI Advice --%>
                  <%= if @ai_advice || @ai_error do %>
                    <div class="glass-card overflow-hidden mt-4">
                      <div class="flex items-center gap-2 px-6 py-3 border-b border-white/5">
                        <.icon name="hero-sparkles" class="size-4 text-violet-400" />
                        <h2 class="text-xs font-medium uppercase tracking-wider text-slate-500">AI Advice</h2>
                      </div>
                      <%= if @ai_error do %>
                        <div class="p-6">
                          <div class="flex items-start gap-3">
                            <.icon name="hero-x-circle" class="size-5 text-red-400 shrink-0 mt-0.5" />
                            <p class="text-sm text-red-400"><%= @ai_error %></p>
                          </div>
                        </div>
                      <% else %>
                        <div class="p-6 prose prose-invert prose-sm max-w-none
                                    prose-headings:text-slate-200 prose-headings:text-sm prose-headings:font-semibold prose-headings:mt-4 prose-headings:mb-2
                                    prose-p:text-slate-300 prose-p:leading-relaxed
                                    prose-li:text-slate-300
                                    prose-code:text-blue-300 prose-code:bg-white/5 prose-code:px-1 prose-code:rounded
                                    prose-strong:text-slate-200">
                          <%= raw(render_markdown(@ai_advice)) %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

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

  defp render_markdown(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(~r/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/`([^`]+)`/, "<code>\\1</code>")
    |> String.replace(~r/^### (.+)$/m, "<h3>\\1</h3>")
    |> String.replace(~r/^## (.+)$/m, "<h2>\\1</h2>")
    |> String.replace(~r/^- (.+)$/m, "<li>\\1</li>")
    |> String.replace(~r/(<li>.*<\/li>\n?)+/s, fn match -> "<ul>#{match}</ul>" end)
    |> String.replace("\n\n", "</p><p>")
    |> then(&"<p>#{&1}</p>")
  end

  defp render_markdown(_), do: ""
end
