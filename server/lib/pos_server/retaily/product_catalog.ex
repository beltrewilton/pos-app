defmodule PosServer.Retaily.ProductCatalog do
  @moduledoc false

  import Ecto.Query

  alias PosServer.{InventoryEvents, Repo}
  alias PosServer.Accounts.Scope
  alias PosServer.Retaily.{Inventory, Pricing, PricingList, Product, Store}

  def pricing_lists(%Scope{tenant: tenant}) do
    Repo.all(from(pricing in Pricing, where: pricing.status == 1, order_by: [asc: pricing.label], select: %{id: pricing.id, label: pricing.label}), prefix: tenant)
  end

  def create(scope, attrs) do
    with true <- Scope.allowed?(scope, "product.add"),
         store_id when is_integer(store_id) and store_id > 0 <- attrs.store_id,
         {:ok, tenant} <- PosServer.Retaily.InventoryContext.authorize_store(scope, store_id),
         :ok <- default_price?(attrs.prices) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      username = scope.login || get_in(scope.user || %{}, [:name]) || "system"

      result = Repo.transaction(fn ->
        product_attrs = %{name: attrs.name, code: attrs.code, cost: attrs.cost, image_raw: attrs.image_raw, active: 1, user_modified: username, date_create: now, archived: "0"}

        with {:ok, product} <- %Product{} |> Product.changeset(product_attrs) |> Repo.insert(prefix: tenant),
             {_, _} <- initialize_inventory(product.id, username, now, tenant),
             :ok <- save_prices(attrs.prices, product.id, username, now, tenant) do
          product
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

      case result do
        {:ok, product} ->
          InventoryEvents.broadcast(tenant, store_id, [product.id])
          {:ok, product}

        error -> error
      end
    else
      false -> {:error, :forbidden}
      _ -> {:error, :invalid_product}
    end
  end

  defp default_price?(prices) do
    if Enum.any?(prices, &(&1.pricing_id == 1 and is_number(&1.price) and &1.price >= 0)), do: :ok, else: {:error, :default_price_required}
  end

  defp initialize_inventory(product_id, username, now, tenant) do
    rows = Repo.all(from(store in Store, select: %{product_id: type(^product_id, :integer), store_id: store.id, quantity: 0, prev_quantity: 0, last_update: type(^now, :naive_datetime), user_updated: type(^username, :string)}), prefix: tenant)
    if rows == [], do: {0, nil}, else: Repo.insert_all(Inventory, rows, prefix: tenant, on_conflict: :nothing, conflict_target: [:product_id, :store_id])
  end

  defp save_prices(prices, product_id, username, now, tenant) do
    Enum.reduce_while(prices, :ok, fn price, :ok ->
      attrs = %{product_id: product_id, pricing_id: price.pricing_id, price: price.price, user_modified: username, date_create: now}
      entry = Repo.one(from(entry in PricingList, where: entry.product_id == ^product_id and entry.pricing_id == ^price.pricing_id, limit: 1), prefix: tenant)
      changeset = if entry, do: PricingList.changeset(entry, attrs), else: PricingList.changeset(%PricingList{}, attrs)
      case Repo.insert_or_update(changeset, prefix: tenant) do {:ok, _} -> {:cont, :ok}; {:error, reason} -> {:halt, {:error, reason}} end
    end)
  end
end
