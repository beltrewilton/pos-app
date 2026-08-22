defmodule PosServer.Accounts.Scope do
  @moduledoc """
  Request authorization scope. Tenant-owned contexts receive this scope from
  the authentication plug instead of accepting a tenant from request params.
  """

  alias PosServer.Accounts.User

  defstruct user: nil

  @doc "Creates a scope for an authenticated user; returns nil when absent."
  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil
end
