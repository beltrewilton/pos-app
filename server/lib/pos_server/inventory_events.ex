defmodule PosServer.InventoryEvents do
  @moduledoc false

  @pubsub PosServer.PubSub

  def topic(tenant, store_id), do: "inventory:#{tenant}:#{store_id}"

  # All inventory consumers subscribe through the same tenant-and-store-scoped
  # topic.  Never use a global inventory topic: terminals must not receive
  # inventory activity from another tenant (or another store).
  def subscribe(tenant, store_id), do: Phoenix.PubSub.subscribe(@pubsub, topic(tenant, store_id))
  def unsubscribe(tenant, store_id), do: Phoenix.PubSub.unsubscribe(@pubsub, topic(tenant, store_id))

  def broadcast(tenant, store_id, product_ids) do
    Phoenix.PubSub.broadcast(@pubsub, topic(tenant, store_id), {
      :inventory_changed,
      %{type: "inventory_changed", product_ids: Enum.uniq(product_ids)}
    })
  end
end
