defmodule PosServerWeb.LandingController do
  use PosServerWeb, :controller

  def index(conn, _params) do
    conn
    |> put_root_layout(html: {PosServerWeb.LandingLayouts, :root})
    |> render(:index)
  end
end
