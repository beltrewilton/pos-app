defmodule PosServerWeb.PricingController do
  use PosServerWeb, :controller

  import Ecto.Query
  alias PosServer.{Repo, TenantContext}
  alias PosServer.Retaily.Pricing

  def index(conn, _params) do
    entries = Repo.all(from(pricing in Pricing, where: pricing.status == 1, order_by: [asc: pricing.label], select: %{id: pricing.id, label: pricing.label, price_key: pricing.price_key}), prefix: TenantContext.tenant!())
    json(conn, %{entries: entries})
  end
end
