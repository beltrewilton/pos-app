defmodule PosServerWeb.StoreController do
  use PosServerWeb, :controller

  alias PosServer.Retaily.InventoryContext

  def index(conn, _params) do
    {:ok, entries} = InventoryContext.stores(conn.assigns.current_scope)
    json(conn, %{entries: entries})
  end
end
