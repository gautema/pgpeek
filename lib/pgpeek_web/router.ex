defmodule PgpeekWeb.Router do
  use PgpeekWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PgpeekWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PgpeekWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/queries", QueriesLive
    live "/queries/:query_id", QueryDetailLive
    live "/diagnose", DiagnoseLive
  end

  # API endpoint for deploy markers
  scope "/api", PgpeekWeb do
    pipe_through :api

    post "/deploys", DeployController, :create
  end
end
