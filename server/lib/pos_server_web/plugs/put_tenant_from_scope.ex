defmodule PosServerWeb.Plugs.PutTenantFromScope do
  @moduledoc """
  Sets the authenticated user's Triplex tenant in the request process.
  """

  alias PosServer.TenantContext

  def init(opts), do: opts

  def call(%{assigns: %{current_scope: %{user: %{tenant: tenant}}}} = conn, _opts)
      when is_binary(tenant) and tenant != "" do
    TenantContext.put_tenant(tenant)
    conn
  end

  def call(conn, _opts), do: conn
end
