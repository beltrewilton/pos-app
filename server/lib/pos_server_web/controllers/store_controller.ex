defmodule PosServerWeb.StoreController do
  use PosServerWeb, :controller

  alias PosServer.Retaily.InventoryContext

  def index(conn, _params) do
    case InventoryContext.stores(conn.assigns.current_scope) do
      {:ok, entries} -> json(conn, %{entries: entries})
      {:error, _} -> conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
    end
  end
end
