defmodule PgpeekWeb.Router do
  use PgpeekWeb, :router

  import PgpeekWeb.Plugs.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PgpeekWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PgpeekWeb.Plugs.Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes (login)
  scope "/", PgpeekWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", SessionController, :new
    post "/login", SessionController, :create
  end

  # Logout (needs auth)
  scope "/", PgpeekWeb do
    pipe_through [:browser, :require_auth]

    delete "/logout", SessionController, :delete
  end

  # Protected LiveView routes
  scope "/", PgpeekWeb do
    pipe_through [:browser, :require_auth]

    live_session :authenticated, on_mount: [{PgpeekWeb.AuthHooks, :require_auth}] do
      live "/", DashboardLive
      live "/queries", QueriesLive
      live "/queries/:query_id", QueryDetailLive
      live "/diagnose", DiagnoseLive
      live "/settings", SettingsLive
    end
  end

  # API endpoint for deploy markers
  scope "/api", PgpeekWeb do
    pipe_through :api

    post "/deploys", DeployController, :create
  end
end
