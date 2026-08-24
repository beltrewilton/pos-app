defmodule PosServer.Retaily.InventoryContext do
  @moduledoc false

  import Ecto.Query

  alias PosServer.{Repo, TenantContext}
  alias PosServer.Retaily.{Inventory, PricingList, Product, Store, User, UserStore}

  def list(scope, store_id, inventory_filter \\ nil) do
    with {:ok, tenant} <- authorize_store(scope, store_id) do
      entries =
        from(inventory in Inventory,
          join: product in Product, on: product.id == inventory.product_id,
          join: store in Store, on: store.id == inventory.store_id,
          left_join: price in subquery(default_prices_query()), on: price.product_id == product.id,
          where: inventory.store_id == ^store_id,
          order_by: [asc: product.name],
          select: %{id: inventory.id, product_id: inventory.product_id, product_name: product.name, product_code: product.code, product_cost: product.cost, product_price: price.price, store_id: inventory.store_id, store_name: store.name, quantity: inventory.quantity, prev_quantity: inventory.prev_quantity, last_update: inventory.last_update, user_updated: inventory.user_updated}
        )
        |> apply_inventory_filter(inventory_filter)
        |> Repo.all(prefix: tenant)

      {:ok, entries}
    end
  end

  def quantities(scope, store_id, product_ids) do
    with {:ok, tenant} <- authorize_store(scope, store_id) do
      entries =
        from(inventory in Inventory,
          where: inventory.store_id == ^store_id and inventory.product_id in ^product_ids,
          select: %{product_id: inventory.product_id, quantity: inventory.quantity}
        )
        |> Repo.all(prefix: tenant)

      {:ok, entries}
    end
  end

  def authorize_store(scope, store_id) do
    with {:ok, cashier, tenant} <- cashier(scope),
         :ok <- cashier_store?(cashier, store_id, tenant) do
      {:ok, tenant}
    end
  end

  defp cashier(%{user: %{name: name}}) when is_binary(name) do
    tenant = TenantContext.tenant!()

    case Repo.one(from(user in User, where: user.username == ^name and user.is_active == 1), prefix: tenant) do
      nil -> {:error, :cashier_not_found}
      user -> {:ok, user, tenant}
    end
  end

  defp cashier(_), do: {:error, :unauthorized}

  defp cashier_store?(cashier, store_id, tenant) do
    if Repo.exists?(from(link in UserStore, where: link.user_id == ^cashier.id and link.store_id == ^store_id), prefix: tenant), do: :ok, else: :error
  end

  defp apply_inventory_filter(query, "negative"), do: where(query, [inventory, _product, _store], inventory.quantity < 0)
  defp apply_inventory_filter(query, "uncosted"), do: where(query, [inventory, product, _store], inventory.quantity > 0 and (is_nil(product.cost) or product.cost <= ^0.0))
  defp apply_inventory_filter(query, _), do: query

  # Pricing id 1 is the existing application default. Keeping this lookup here
  # makes inventory price presentation independent from product.cost and legacy product.price.
  defp default_prices_query do
    from(entry in PricingList,
      where: entry.pricing_id == 1,
      distinct: entry.product_id,
      order_by: [asc: entry.product_id, desc: entry.id],
      select: %{product_id: entry.product_id, price: entry.price}
    )
  end
end
