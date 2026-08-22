defmodule PosServerWeb.HealthController do
  use PosServerWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
