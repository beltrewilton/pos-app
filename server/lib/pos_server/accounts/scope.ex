defmodule PosServer.Accounts.Scope do
  @moduledoc """
  Request authorization scope. Tenant-owned contexts receive this scope from
  the authentication plug instead of accepting a tenant from request params.
  """

  alias PosServer.Accounts.User

  defstruct user: nil, store_id: nil

  @doc "Creates a scope for an authenticated user; returns nil when absent."
  def for_user(%User{} = user), do: for_user(user, [])
  def for_user(nil), do: nil
  def for_user(%User{} = user, opts), do: %__MODULE__{user: user, store_id: Keyword.get(opts, :store_id)}
end
