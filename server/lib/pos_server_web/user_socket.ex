defmodule PosServerWeb.UserSocket do
  use Phoenix.Socket

  channel "system:*", PosServerWeb.SystemChannel

  @tenant "educa"
  @store_id 2

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, assign(socket, tenant: @tenant, store_id: @store_id)}

  @impl true
  def id(_socket), do: nil
end
