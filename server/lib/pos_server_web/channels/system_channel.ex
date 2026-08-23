defmodule PosServerWeb.SystemChannel do
  use PosServerWeb, :channel

  alias PosServer.InventoryEvents

  @impl true
  def join("system:health", _payload, socket), do: {:ok, socket}
  def join("inventory:" <> topic, _payload, socket) do
    if topic == InventoryEvents.topic(socket.assigns.tenant, socket.assigns.store_id) do
      Phoenix.PubSub.subscribe(PosServer.PubSub, topic)
      {:ok, socket}
    else
      {:error, %{reason: "unsupported_topic"}}
    end
  end
  def join(_topic, _payload, _socket), do: {:error, %{reason: "unsupported_topic"}}

  @impl true
  def handle_info({:inventory_changed, payload}, socket) do
    push(socket, "inventory_changed", payload)
    {:noreply, socket}
  end
end
