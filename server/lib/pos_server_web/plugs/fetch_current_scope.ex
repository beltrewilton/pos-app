defmodule PosServerWeb.Plugs.FetchCurrentScope do
  @moduledoc """
  Resolves a desktop API bearer token to the same `current_scope` shape used
  by browser requests. The token is URL-safe Base64 encoded because session
  tokens are stored as binary.
  """

  import Plug.Conn

  alias PosServer.Accounts
  alias PosServer.Accounts.Scope

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn |> get_req_header("authorization") |> bearer_user()
    assign(conn, :current_scope, Scope.for_user(user))
  end

  defp bearer_user(["Bearer " <> encoded_token]) do
    with {:ok, token} <- Base.url_decode64(encoded_token, padding: false) do
      Accounts.get_user_by_session_token(token)
    else
      _ -> nil
    end
  end

  defp bearer_user(_), do: nil
end
