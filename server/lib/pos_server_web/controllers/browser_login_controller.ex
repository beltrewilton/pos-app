defmodule PosServerWeb.BrowserLoginController do
  use PosServerWeb, :controller

  alias PosServer.{Authentication, TenantContext}
  alias PosServer.Retaily.InventoryContext

  def create(conn, %{"token" => token, "store_id" => store_id}) do
    with {:ok, scope} <- Authentication.authenticate(token),
         _ <- TenantContext.put_tenant(scope.tenant),
         {store_id, ""} <- Integer.parse(to_string(store_id)),
         {:ok, _} <- InventoryContext.authorize_store(scope, store_id) do
      conn
      |> configure_session(renew: true)
      |> put_session(:user_token, token)
      |> put_session(:store_id, store_id)
      |> json(%{redirect_to: ~p"/pos"})
    else
      _ -> conn |> put_status(:unauthorized) |> json(%{error: "invalid login session"})
    end
  end

  def create(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "invalid login session"})

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/pos/login")
  end
end
