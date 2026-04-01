defmodule PgpeekWeb.DeployControllerTest do
  use PgpeekWeb.ConnCase

  alias Pgpeek.Repo
  alias Pgpeek.Schemas.Deploy

  describe "POST /api/deploys" do
    test "creates a deploy with description", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/deploys", %{description: "v1.2.3 release"})

      assert %{"id" => id, "description" => "v1.2.3 release"} = json_response(conn, 201)
      assert Repo.get(Deploy, id)
    end

    test "creates a deploy without description", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/deploys", %{})

      assert %{"id" => id} = json_response(conn, 201)
      deploy = Repo.get(Deploy, id)
      assert deploy
      assert deploy.deployed_at
    end

    test "sets deployed_at to current time", %{conn: conn} do
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/deploys", %{description: "test"})

      %{"id" => id} = json_response(conn, 201)
      deploy = Repo.get(Deploy, id)

      assert DateTime.compare(deploy.deployed_at, before) in [:gt, :eq]
    end
  end
end
