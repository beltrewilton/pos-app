defmodule PosServerWeb.Plugs.FetchCurrentScope do
  @moduledoc "Loads the authenticated admin or employee from a bearer token."

  import Plug.Conn

  alias PosServer.Authentication

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer", token] <- Plug.Conn.get_req_header(conn, "authorization") |> List.first() |> to_string() |> String.split(" ", parts: 2),
         {:ok, scope} <- Authentication.authenticate(token) do
      assign(conn, :current_scope, scope)
    else
      _ -> conn
    end
  end
end
