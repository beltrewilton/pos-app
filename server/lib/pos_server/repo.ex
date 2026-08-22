defmodule PosServer.Repo do
  use Ecto.Repo,
    otp_app: :pos_server,
    adapter: Ecto.Adapters.Postgres
end
