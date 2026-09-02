defmodule PosServerWeb.DashboardController do
  use PosServerWeb, :controller

  alias PosServer.Accounts

  def index(%{assigns: %{current_scope: %{actor: :admin, actor_id: user_id}}} = conn, _params) do
    case Accounts.get_user(user_id) do
      nil -> redirect(conn, to: ~p"/")
      user -> render(conn, :index, user: user)
    end
  end

  def index(conn, _params), do: redirect(conn, to: ~p"/")
end
