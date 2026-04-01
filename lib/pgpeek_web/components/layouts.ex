defmodule PgpeekWeb.Layouts do
  @moduledoc false
  use PgpeekWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <nav class="glass-card sticky top-0 z-40 mx-4 mt-4 mb-6 sm:mx-6 lg:mx-8">
      <div class="flex h-14 items-center justify-between px-6">
        <div class="flex items-center gap-8">
          <a href="/" class="flex items-center gap-2 group">
            <div class="flex items-center justify-center size-8 rounded-lg bg-blue-500/20">
              <.icon name="hero-chart-bar-square" class="size-5 text-blue-400" />
            </div>
            <span class="text-base font-bold text-white tracking-tight">PgPeek</span>
          </a>
          <div class="hidden sm:flex items-center gap-1">
            <.nav_link href="/" icon="hero-squares-2x2" label="Dashboard" />
            <.nav_link href="/queries" icon="hero-command-line" label="Queries" />
            <.nav_link href="/diagnose" icon="hero-wrench-screwdriver" label="Diagnose" />
          </div>
        </div>
        <div class="flex items-center gap-4">
          <.connection_indicator />
          <%= if @current_user do %>
            <div class="flex items-center gap-3">
              <.link
                navigate="/settings"
                class="text-xs text-slate-500 hover:text-slate-300 transition-colors"
              >
                <.icon name="hero-cog-6-tooth" class="size-4" />
              </.link>
              <.link
                href="/logout"
                method="delete"
                class="text-xs text-slate-500 hover:text-slate-300 transition-colors"
              >
                Sign out
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </nav>

    <main class="mx-auto max-w-7xl px-4 pb-12 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-slate-400 hover:text-white hover:bg-white/5 transition-colors"
    >
      <.icon name={@icon} class="size-4" />
      {@label}
    </a>
    """
  end

  defp connection_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-1.5 text-xs text-slate-500">
      <span class="relative flex size-2">
        <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75">
        </span>
        <span class="relative inline-flex size-2 rounded-full bg-emerald-500"></span>
      </span>
      <span class="hidden sm:inline">Connected</span>
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="fixed top-4 right-4 z-50 space-y-2" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
