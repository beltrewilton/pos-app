defmodule PosServerWeb.Plugs.RequirePermission do
  @moduledoc "Applies the imported Retaily scope names to tenant API requests."
  import Plug.Conn
  alias PosServer.Accounts.Scope

  def init(opts), do: opts

  def call(%{assigns: %{current_scope: scope}} = conn, _opts) do
    case permission(conn.method, conn.request_path) do
      nil -> conn
      permission ->
        if Scope.allowed?(scope, permission) do
          conn
        else
          conn |> put_resp_content_type("application/json") |> send_resp(:forbidden, ~s({"error":"forbidden"})) |> halt()
        end
    end
  end

  def call(conn, _opts), do: conn

  defp permission(method, path) do
    cond do
      path == "/api/users" and method == "GET" -> "user.view"
      path == "/api/users" and method == "POST" -> "user.setting"
      String.starts_with?(path, "/api/users/") and method == "GET" -> "user.view"
      String.starts_with?(path, "/api/users/") and method in ["PATCH", "DELETE"] -> "user.setting"
      String.starts_with?(path, "/api/products") and method == "GET" -> "product.view"
      path == "/api/stores" and method == "GET" -> "product.view"
      path == "/api/products" and method == "POST" -> "product.add"
      String.starts_with?(path, "/api/products/") and method in ["PATCH", "POST"] -> "product.edit"
      String.starts_with?(path, "/api/company-settings") -> "company.settings"
      String.starts_with?(path, "/api/inventory") and method == "GET" -> "inventory.view"
      path == "/api/inventory/adjustments" and method == "POST" -> "inventory.stores"
      String.starts_with?(path, "/api/sales") and method == "GET" -> "sales.view"
      String.starts_with?(path, "/api/sales") and method == "POST" -> "sales.pos"
      (String.starts_with?(path, "/api/product-orders") or String.starts_with?(path, "/api/purchase-sources")) and method == "GET" -> "inventory.view"
      String.starts_with?(path, "/api/product-orders") and method == "POST" -> "inventory.movement.request"
      true -> nil
    end
  end
end
