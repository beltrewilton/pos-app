defmodule PosServerWeb.AuthController do
  use PosServerWeb, :controller

  alias PosServer.Authentication

  def login(conn, params) do
    case Authentication.login(params) do
      {:ok, token, scope} -> json(conn, %{token: token, user: %{type: scope.actor, id: scope.actor_id, login: scope.login, tenant: scope.tenant, store_ids: scope.store_ids, scopes: scope.scopes}})
      {:error, :invalid_credentials} -> conn |> put_status(:unauthorized) |> json(%{error: "invalid credentials"})
    end
  end
end
