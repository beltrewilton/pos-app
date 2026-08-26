defmodule PosServerWeb.SystemChannel do
  use PosServerWeb, :channel

  alias PosServer.{InventoryEvents, PrintRelay}
  alias PosServer.Accounts.Scope
  alias PosServerWeb.Presence

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
  def join("print-relay:" <> store_id, payload, socket) do
    with {store_id, ""} <- Integer.parse(store_id),
         true <- allowed_store?(socket.assigns.scope, store_id),
         {:ok, socket} <- join_print_relay(payload, socket, store_id) do
      {:ok, %{targets: PrintRelay.available_desktops(socket.assigns.tenant, store_id)}, socket}
    else
      _ -> {:error, %{reason: "unauthorized_or_invalid_print_session"}}
    end
  end
  def join(_topic, _payload, _socket), do: {:error, %{reason: "unsupported_topic"}}

  @impl true
  def handle_info({:inventory_changed, payload}, socket) do
    push(socket, "inventory_changed", payload)
    {:noreply, socket}
  end

  def handle_info({:print_request, payload}, socket) do
    push(socket, "print_request", payload)
    {:noreply, socket}
  end

  def handle_info({:print_result, payload}, socket) do
    push(socket, "print_result", payload)
    {:noreply, socket}
  end

  def handle_info(:session_expired, socket) do
    if socket.assigns[:print_relay] do
      Presence.untrack(self(), socket.assigns.print_relay.topic, socket.assigns.print_relay.session_id)
    end

    {:stop, :normal, socket}
  end

  @impl true
  def handle_in("printer_status", %{"printer_online" => online} = payload, socket) when is_boolean(online) do
    case socket.assigns[:print_relay] do
      %{device: "desktop"} = relay ->
        meta = %{device: "desktop", label: payload["label"] || relay.label, printer: payload["printer"] || relay.printer, printer_online: online, user: relay.user}
        {:ok, _} = Presence.update(self(), relay.topic, relay.session_id, fn _ -> meta end)
        {:reply, {:ok, %{targets: PrintRelay.available_desktops(socket.assigns.tenant, relay.store_id)}}, socket}

      _ -> {:reply, {:error, %{reason: "desktop_session_required"}}, socket}
    end
  end

  def handle_in("print", %{"request_id" => request_id, "target_session_id" => target, "receipt" => receipt}, socket)
      when is_binary(request_id) and byte_size(request_id) in 16..128 and is_binary(target) and is_map(receipt) do
    relay = socket.assigns[:print_relay]

    if relay && PrintRelay.available_desktop?(socket.assigns.tenant, relay.store_id, target) do
      Phoenix.PubSub.subscribe(PosServer.PubSub, PrintRelay.result_topic(socket.assigns.tenant, relay.store_id, request_id))
      Phoenix.PubSub.broadcast(PosServer.PubSub, PrintRelay.desktop_topic(socket.assigns.tenant, relay.store_id, target), {:print_request, %{request_id: request_id, receipt: receipt}})
      {:reply, {:ok, %{request_id: request_id, status: "queued"}}, socket}
    else
      {:reply, {:error, %{request_id: request_id, reason: "selected_printer_unavailable"}}, socket}
    end
  end

  def handle_in("print_result", %{"request_id" => request_id, "status" => status} = payload, socket)
      when is_binary(request_id) and status in ["success", "failed"] do
    case socket.assigns[:print_relay] do
      %{device: "desktop"} = relay ->
        Phoenix.PubSub.broadcast(PosServer.PubSub, PrintRelay.result_topic(socket.assigns.tenant, relay.store_id, request_id), {:print_result, Map.take(payload, ["request_id", "status", "message"])})
        {:reply, :ok, socket}

      _ -> {:reply, {:error, %{reason: "desktop_session_required"}}, socket}
    end
  end

  def handle_in(_, _, socket), do: {:reply, {:error, %{reason: "unsupported_event"}}, socket}

  defp join_print_relay(payload, socket, store_id) do
    device = payload["device"]
    session_id = payload["session_id"]

    if device in ["mobile", "desktop"] and is_binary(session_id) and byte_size(session_id) in 16..128 do
      topic = PrintRelay.topic(socket.assigns.tenant, store_id)
      relay = %{topic: topic, store_id: store_id, device: device, session_id: session_id, label: payload["label"] || device_label(device), printer: payload["printer"] || "Receipt printer", user: socket.assigns.scope.login}

      if device == "desktop" do
        Phoenix.PubSub.subscribe(PosServer.PubSub, PrintRelay.desktop_topic(socket.assigns.tenant, store_id, session_id))
      end

      {:ok, _} = Presence.track(self(), topic, session_id, %{device: device, label: relay.label, printer: relay.printer, printer_online: device == "desktop" and payload["printer_online"] == true, user: relay.user})

      milliseconds = max(socket.assigns.session_expires_at - System.system_time(:second), 0) * 1_000
      Process.send_after(self(), :session_expired, milliseconds)
      {:ok, assign(socket, print_relay: relay)}
    else
      :error
    end
  end

  defp allowed_store?(scope, store_id), do: Scope.admin?(scope) or store_id in scope.store_ids
  defp device_label("desktop"), do: "Desktop Tauri"
  defp device_label(_), do: "Mobile POS"
end
