defmodule PosServer.Retaily.InventoryContext do
  @moduledoc false

  import Ecto.Query

  alias PosServer.{Repo, TenantContext}
  alias PosServer.Retaily.{Inventory, User, UserStore}

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
end
