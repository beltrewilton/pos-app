defmodule PosServerWeb.LandingController do
  use PosServerWeb, :controller

  alias PosServer.Accounts

  def index(conn, _params) do
    current_user =
      case conn.assigns[:current_scope] do
        %{actor: :admin, actor_id: user_id} -> Accounts.get_user(user_id)
        _ -> nil
      end

    conn
    |> put_root_layout(html: {PosServerWeb.LandingLayouts, :root})
    |> render(:index, current_user: current_user)
  end
end
