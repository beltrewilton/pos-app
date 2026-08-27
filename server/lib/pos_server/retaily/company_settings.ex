defmodule PosServer.Retaily.CompanySettings do
  @moduledoc false

  import Ecto.Query

  alias PosServer.{Repo, TenantContext}
  alias PosServer.Accounts.{Company, UserCompany}
  alias PosServer.Retaily.{Pricing, PricingList, Store}

  def overview(scope) do
    tenant = TenantContext.tenant!()

    {:ok,
     %{company: company(scope), price_lists: list_price_lists(tenant), stores: list_stores(tenant)}}
  end

  def create_price_list(scope, attrs), do: save_price_list(scope, %Pricing{}, attrs)

  def update_price_list(scope, id, attrs) do
    with %Pricing{} = pricing <- Repo.get(Pricing, id, prefix: TenantContext.tenant!()) do
      save_price_list(scope, pricing, attrs)
    else
      nil -> {:error, :not_found}
    end
  end

  def delete_price_list(id) do
    tenant = TenantContext.tenant!()

    Repo.transaction(fn ->
      case Repo.get(Pricing, id, prefix: tenant) do
        nil -> Repo.rollback(:not_found)
        pricing ->
          Repo.delete_all(from(entry in PricingList, where: entry.pricing_id == ^pricing.id), prefix: tenant)
          Repo.delete!(pricing, prefix: tenant)
      end
    end)
    |> transaction_result()
  end

  def create_store(scope, attrs), do: save_store(scope, %Store{}, attrs)

  def update_store(scope, id, attrs) do
    with %Store{} = store <- Repo.get(Store, id, prefix: TenantContext.tenant!()) do
      save_store(scope, store, attrs)
    else
      nil -> {:error, :not_found}
    end
  end

  def delete_store(id) do
    case Repo.get(Store, id, prefix: TenantContext.tenant!()) do
      nil -> {:error, :not_found}
      store -> Repo.delete(store, prefix: TenantContext.tenant!()) |> write_result()
    end
  end

  defp save_price_list(scope, pricing, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    label = attrs["label"] || attrs[:label]
    values = %{label: label, price_key: price_key(label), user_modified: scope.user.name, status: 1, date_create: pricing.date_create || now}

    pricing
    |> Pricing.changeset(values)
    |> Repo.insert_or_update(prefix: TenantContext.tenant!())
    |> write_result()
  end

  defp save_store(scope, store, attrs) do
    company_id = company(scope).id
    values = Map.take(attrs, ["name", "address", "slogan"])
      |> Map.merge(%{"company_id" => to_string(company_id), "date_create" => store.date_create || NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)})

    store
    |> Store.changeset(values)
    |> Repo.insert_or_update(prefix: TenantContext.tenant!())
    |> write_result()
  end

  defp list_price_lists(tenant), do: Repo.all(from(pricing in Pricing, order_by: [asc: pricing.label], select: %{id: pricing.id, label: pricing.label, price_key: pricing.price_key, status: pricing.status}), prefix: tenant)
  defp list_stores(tenant), do: Repo.all(from(store in Store, order_by: [asc: store.name], select: %{id: store.id, name: store.name, address: store.address, slogan: store.slogan, company_id: store.company_id}), prefix: tenant)

  defp company(%{actor: :admin, actor_id: user_id}) do
    Repo.one!(from(company in Company, join: membership in UserCompany, on: membership.company_id == company.id, where: membership.user_id == ^user_id, limit: 1, select: %{id: company.id, name: company.company_name, rnc: company.rnc}), prefix: TenantContext.tenant!())
  end
  defp company(scope), do: %{id: scope.tenant, name: scope.tenant, rnc: nil}

  defp price_key(label) when is_binary(label) do
    key =
      label
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")

    if key == "", do: "price_list", else: key
  end
  defp price_key(_), do: "price_list"
  defp write_result({:ok, value}), do: {:ok, value}
  defp write_result({:error, value}), do: {:error, value}
  defp transaction_result({:ok, value}), do: {:ok, value}
  defp transaction_result({:error, value}), do: {:error, value}
end
