defmodule PosServer.Retaily.BusinessTime do
  @moduledoc false

  import Ecto.Query

  alias PosServer.{Repo, TenantContext}
  alias PosServer.Accounts.Company

  @default_timezone_offset -4

  def local_now(tenant \\ nil) do
    DateTime.utc_now()
    |> DateTime.add(timezone_offset(tenant), :hour)
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end

  def timezone_offset(tenant \\ nil) do
    tenant = tenant || TenantContext.get_tenant()

    if is_binary(tenant) do
      Repo.one(from(company in Company, select: company.timezone_offset, limit: 1), prefix: tenant) ||
        @default_timezone_offset
    else
      @default_timezone_offset
    end
  rescue
    _ -> @default_timezone_offset
  end
end
