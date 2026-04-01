defmodule PgpeekWeb.QueryDetailLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Snapshots
  alias Pgpeek.Diagnostics

  @impl true
  def mount(%{"query_id" => query_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pgpeek.PubSub, "snapshots")
    end

    socket =
      socket
      |> assign(:page_title, "Query Detail")
      |> assign(:query_id, query_id)
      |> assign(:explain_plan, nil)
      |> assign(:explain_loading, false)
      |> assign(:explain_error, nil)
      |> load_query_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("explain", _params, socket) do
    socket = assign(socket, :explain_loading, true)
    send(self(), :run_explain)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_snapshot, _id}, socket) do
    {:noreply, load_query_data(socket)}
  end

  def handle_info(:run_explain, socket) do
    {plan, error} =
      case Diagnostics.explain(socket.assigns.query_text) do
        {:ok, plan} -> {plan, nil}
        {:error, msg} -> {nil, to_string(msg)}
      end

    socket =
      socket
      |> assign(:explain_plan, plan)
      |> assign(:explain_error, error)
      |> assign(:explain_loading, false)

    {:noreply, socket}
  end

  defp load_query_data(socket) do
    query_id = socket.assigns.query_id
    history = Snapshots.query_history(query_id)

    latest =
      case history do
        [h | _] -> h
        [] -> nil
      end

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
      |> limit(1)
      |> Pgpeek.Repo.one()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div>
          <.link navigate={~p"/queries"} class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-blue-400 transition-colors mb-3">
            <.icon name="hero-arrow-left-micro" class="size-4" />
            Back to queries
          </.link>
          <h1 class="text-2xl font-bold text-white">Query Detail</h1>
          <p class="mt-1 text-xs font-mono text-slate-500 truncate max-w-2xl">
            ID: <%= @query_id %>
          </p>
        </div>

        <%!-- Query Text --%>
        <div class="glass-card overflow-hidden">
          <div class="flex items-center justify-between px-6 py-3 border-b border-white/5">
            <div class="flex items-center gap-2">
              <.icon name="hero-code-bracket" class="size-4 text-slate-500" />
              <h2 class="text-xs font-medium uppercase tracking-wider text-slate-500">Query Text</h2>
            </div>
            <%= if @query_text do %>
              <button
                phx-click="explain"
                disabled={@explain_loading}
                class={[
                  "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors",
                  if(@explain_loading,
                    do: "bg-white/5 text-slate-500 cursor-wait",
                    else: "bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 cursor-pointer"
                  )
                ]}
              >
                <%= if @explain_loading do %>
                  <.icon name="hero-arrow-path" class="size-3.5 animate-spin" />
                  Running...
                <% else %>
                  <.icon name="hero-play" class="size-3.5" />
                  Explain Plan
                <% end %>
              </button>
            <% end %>
          </div>
          <div class="p-6">
            <pre class="overflow-x-auto text-sm font-mono text-slate-300 leading-relaxed whitespace-pre-wrap"><%= @query_text || "(not available)" %></pre>
          </div>
        </div>

        <%!-- Explain Plan --%>
        <%= if @explain_plan || @explain_error do %>
          <div class="glass-card overflow-hidden">
            <div class="flex items-center gap-2 px-6 py-3 border-b border-white/5">
              <.icon name="hero-map" class="size-4 text-slate-500" />
              <h2 class="text-xs font-medium uppercase tracking-wider text-slate-500">Execution Plan</h2>
              <span class="text-xs text-slate-600">(GENERIC_PLAN)</span>
            </div>
            <%= if @explain_error do %>
              <div class="p-6">
                <div class="flex items-start gap-3">
                  <.icon name="hero-x-circle" class="size-5 text-red-400 shrink-0 mt-0.5" />
                  <div>
                    <p class="text-sm text-red-400"><%= @explain_error %></p>
                    <p class="text-xs text-slate-500 mt-1">
                      EXPLAIN (GENERIC_PLAN) requires PostgreSQL 16+.
                      Some queries (DDL, utility commands) cannot be explained.
                    </p>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="p-6">
                <pre class="overflow-x-auto text-sm font-mono text-slate-300 leading-relaxed whitespace-pre-wrap"><%= @explain_plan %></pre>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- Stat Cards --%>
        <%= if @latest do %>
          <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <.mini_stat label="Mean Time" value={format_time(@latest.mean_exec_time)} icon="hero-clock" color="blue" />
            <.mini_stat label="Total Time" value={format_time(@latest.total_exec_time)} icon="hero-fire" color="orange" />
            <.mini_stat label="Calls" value={format_number(@latest.calls)} icon="hero-arrow-path" color="violet" />
            <.mini_stat label="Rows" value={format_number(@latest.rows)} icon="hero-table-cells" color="emerald" />
          </div>
        <% end %>

        <%!-- History Table --%>
        <div class="glass-card overflow-hidden">
          <div class="flex items-center gap-2 px-6 py-4 border-b border-white/5">
            <.icon name="hero-chart-bar" class="size-5 text-slate-500" />
            <h2 class="text-base font-semibold text-white">
              History
              <span class="text-sm font-normal text-slate-500">
                (last <%= length(@history) %> snapshots)
              </span>
            </h2>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="border-b border-white/5">
                  <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500">Time</th>
                  <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Mean Time</th>
                  <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Total Time</th>
                  <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Calls</th>
                  <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500">Rows</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <%= for {h, i} <- Enum.with_index(@history) do %>
                  <tr class={["hover:bg-white/[0.02] transition-colors", i == 0 && "bg-blue-500/[0.03]"]}>
                    <td class="whitespace-nowrap px-6 py-3 text-sm text-slate-400">
                      <div class="flex items-center gap-2">
                        <%= if i == 0 do %>
                          <span class="flex size-1.5 rounded-full bg-blue-400"></span>
                        <% end %>
                        <%= Calendar.strftime(h.captured_at, "%Y-%m-%d %H:%M") %>
                      </div>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-300">
                      <%= format_time(h.mean_exec_time) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                      <%= format_time(h.total_exec_time) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                      <%= format_number(h.calls) %>
                    </td>
                    <td class="whitespace-nowrap px-4 py-3 text-right text-sm tabular-nums text-slate-400">
                      <%= format_number(h.rows) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @history == [] do %>
              <div class="px-6 py-16 text-center">
                <div class="mx-auto flex items-center justify-center size-10 rounded-full bg-white/5 mb-3">
                  <.icon name="hero-chart-bar" class="size-5 text-slate-500" />
                </div>
                <p class="text-sm text-slate-500">No history for this query yet.</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp mini_stat(assigns) do
    color_classes = %{
      "blue" => "text-blue-400",
      "orange" => "text-orange-400",
      "violet" => "text-violet-400",
      "emerald" => "text-emerald-400"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, "text-white"))

    ~H"""
    <div class="glass-card p-4">
      <div class="flex items-center gap-2 mb-2">
        <.icon name={@icon} class={"size-3.5 #{@color_class}"} />
        <p class="text-xs font-medium text-slate-500">{@label}</p>
      </div>
      <p class="text-xl font-bold text-white tabular-nums">{@value}</p>
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
