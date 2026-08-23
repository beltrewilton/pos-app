defmodule PosServerWeb.Plugs.FetchCurrentScope do
  @moduledoc """
  Development-only desktop authentication. The POS is bound to the imported
  `educa` tenant and its fixed cashier instead of requiring a bearer token.
  """

  import Plug.Conn

  alias PosServer.Accounts.{Scope, User}

  @tenant "educa"
  @cashier "walex"

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :current_scope, Scope.for_user(%User{name: @cashier, tenant: @tenant}))
  end
end
