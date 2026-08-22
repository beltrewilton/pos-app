defmodule PosServerWeb.UserSocket do
  use Phoenix.Socket

  # Channel topics will be added with their domain features.
  channel "system:*", PosServerWeb.SystemChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
