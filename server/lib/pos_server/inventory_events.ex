defmodule PosServer.InventoryEvents do
  @moduledoc false

  @pubsub PosServer.PubSub

  def topic(tenant, store_id), do: "inventory:#{tenant}:#{store_id}"

  def broadcast(tenant, store_id, product_ids) do
    Phoenix.PubSub.broadcast(@pubsub, topic(tenant, store_id), {
      :inventory_changed,
      %{type: "inventory_changed", product_ids: Enum.uniq(product_ids)}
    })
  end
end
