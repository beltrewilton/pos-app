defmodule PosServerWeb.SystemChannel do
  use PosServerWeb, :channel

  # Placeholder channel foundation. POS domain topics are intentionally deferred.
  @impl true
  def join("system:health", _payload, socket), do: {:ok, socket}
  def join(_topic, _payload, _socket), do: {:error, %{reason: "unsupported_topic"}}
end
