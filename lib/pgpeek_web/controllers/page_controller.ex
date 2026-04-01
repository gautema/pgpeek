defmodule PgpeekWeb.PageController do
  use PgpeekWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
