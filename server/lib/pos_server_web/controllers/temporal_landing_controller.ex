defmodule PosServerWeb.TemporalLandingController do
  use PosServerWeb, :controller

  def index(conn, _params) do
    conn
    |> put_root_layout(html: {PosServerWeb.TemporalLandingLayouts, :root})
    |> render(:index)
  end
end
