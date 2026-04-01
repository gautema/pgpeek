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
    <%!-- Top nav bar --%>
    <nav class="glass-card sticky top-0 z-40 mx-3 mt-3 mb-4 sm:mx-6 sm:mt-4 sm:mb-6 lg:mx-8">
      <div class="flex h-12 sm:h-14 items-center justify-between px-4 sm:px-6">
        <div class="flex items-center gap-6 sm:gap-8">
          <a href="/" class="flex items-center gap-2">
            <div class="flex items-center justify-center size-7 sm:size-8 rounded-lg bg-blue-500/20">
              <.icon name="hero-chart-bar-square" class="size-4 sm:size-5 text-blue-400" />
            </div>
            <span class="text-sm sm:text-base font-bold text-white tracking-tight">PgPeek</span>
          </a>
          <%!-- Desktop nav links --%>
          <div class="hidden sm:flex items-center gap-1">
            <.nav_link href="/" icon="hero-squares-2x2" label="Dashboard" />
            <.nav_link href="/queries" icon="hero-command-line" label="Queries" />
            <.nav_link href="/diagnose" icon="hero-wrench-screwdriver" label="Diagnose" />
          </div>
        </div>
        <div class="flex items-center gap-3 sm:gap-4">
          <.connection_indicator />
          <%= if @current_user do %>
            <div class="flex items-center gap-2 sm:gap-3">
              <.link
                navigate="/settings"
                class="text-xs text-slate-500 hover:text-slate-300 transition-colors"
              >
                <.icon name="hero-cog-6-tooth" class="size-4" />
              </.link>
              <.link
                href="/logout"
                method="delete"
                class="hidden sm:inline text-xs text-slate-500 hover:text-slate-300 transition-colors"
              >
                Sign out
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </nav>

    <%!-- Main content with bottom padding for mobile nav --%>
    <main class="mx-auto max-w-7xl px-3 pb-24 sm:px-6 sm:pb-12 lg:px-8">
      {render_slot(@inner_block)}
    </main>

    <%!-- Mobile bottom nav --%>
    <nav class="sm:hidden fixed bottom-0 inset-x-0 z-40 glass-card rounded-none border-t border-white/5">
      <div class="flex items-center justify-around h-14 px-2">
        <.mobile_nav_link href="/" icon="hero-squares-2x2" label="Dashboard" />
        <.mobile_nav_link href="/queries" icon="hero-command-line" label="Queries" />
        <.mobile_nav_link href="/diagnose" icon="hero-wrench-screwdriver" label="Diagnose" />
        <.mobile_nav_link href="/settings" icon="hero-cog-6-tooth" label="Settings" />
      </div>
    </nav>

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

  defp mobile_nav_link(assigns) do
    ~H"""
    <a href={@href} class="flex flex-col items-center gap-0.5 px-3 py-1.5 text-slate-400">
      <.icon name={@icon} class="size-5" />
      <span class="text-[10px] font-medium">{@label}</span>
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
