defmodule PosServerWeb.PageController do
  use PosServerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
