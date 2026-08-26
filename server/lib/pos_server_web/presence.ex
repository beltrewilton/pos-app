defmodule PosServerWeb.Presence do
  use Phoenix.Presence,
    otp_app: :pos_server,
    pubsub_server: PosServer.PubSub
end
