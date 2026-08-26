defmodule PosServerWeb.UserSocket do
  use Phoenix.Socket

  channel "system:*", PosServerWeb.SystemChannel
  channel "inventory:*", PosServerWeb.SystemChannel
  channel "print-relay:*", PosServerWeb.SystemChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case PosServer.Authentication.authenticate(token) do
      {:ok, scope} ->
        {:ok, assign(socket, scope: scope, tenant: scope.tenant, session_expires_at: System.system_time(:second) + 86_400)}

      {:error, _} ->
        :error
    end
  end

  def connect(_, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
