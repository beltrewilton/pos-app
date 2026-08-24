defmodule PosServerWeb.ProductCreateController do
  use PosServerWeb, :controller

  import Ecto.Query
  alias Ecto.Changeset
  alias PosServer.{Repo, TenantContext}
  alias PosServer.Retaily.{Inventory, InventoryContext, PricingList, Product}

  def create(conn, attrs) do
    with {:ok, store_id} <- positive_integer(attrs["store_id"]),
         {:ok, tenant} <- InventoryContext.authorize_store(conn.assigns.current_scope, store_id) do
      username = conn.assigns.current_scope.user.name
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      Repo.transaction(fn ->
        product_attrs = Map.take(attrs, ["name", "cost", "margin", "code", "img_path", "image_raw", "active"])
          |> Map.merge(%{"active" => attrs["active"] || 1, "user_modified" => username, "date_create" => now, "archived" => "0"})

        with {:ok, product} <- %Product{} |> Product.changeset(product_attrs) |> Repo.insert(prefix: tenant),
             {:ok, _inventory} <- %Inventory{} |> Inventory.changeset(%{product_id: product.id, store_id: store_id, quantity: 0, prev_quantity: 0, last_update: now, user_updated: username}) |> Repo.insert(prefix: tenant) do
          product_response(product)
        else
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
      |> case do
        {:ok, product} -> conn |> put_status(:created) |> json(product)
        {:error, %Changeset{} = changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: Changeset.traverse_errors(changeset, fn {message, _} -> message end)})
      end
    else
      {:error, :invalid_params} -> conn |> put_status(:bad_request) |> json(%{error: "store_id is required"})
      :error -> conn |> put_status(:forbidden) |> json(%{error: "store is not assigned to cashier"})
    end
  end

  def show(conn, %{"id" => id}) do
    tenant = TenantContext.tenant!()

    with {:ok, product_id} <- positive_integer(id),
         %Product{} = product <- Repo.get(Product, product_id, prefix: tenant) do
      prices = Repo.all(from(entry in PricingList, where: entry.product_id == ^product.id, select: %{pricing_id: entry.pricing_id, price: entry.price}), prefix: tenant)
      json(conn, Map.put(product_response(product), :prices, prices))
    else
      {:error, :invalid_params} -> conn |> put_status(:bad_request) |> json(%{error: "invalid product id"})
      nil -> conn |> put_status(:not_found) |> json(%{error: "product not found"})
    end
  end

  def update(conn, %{"id" => id} = attrs) do
    tenant = TenantContext.tenant!()

    with {:ok, product_id} <- positive_integer(id),
         %Product{} = product <- Repo.get(Product, product_id, prefix: tenant) do
      product_attrs = Map.take(attrs, ["name", "cost", "margin", "code", "img_path", "image_raw", "active"])
        |> Map.put("user_modified", conn.assigns.current_scope.user.name)

      case product |> Product.changeset(product_attrs) |> Repo.update(prefix: tenant) do
        {:ok, updated} -> json(conn, product_response(updated))
        {:error, %Changeset{} = changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: Changeset.traverse_errors(changeset, fn {message, _} -> message end)})
      end
    else
      {:error, :invalid_params} -> conn |> put_status(:bad_request) |> json(%{error: "invalid product id"})
      nil -> conn |> put_status(:not_found) |> json(%{error: "product not found"})
    end
  end

  def set_prices(conn, %{"prices" => prices}) when is_list(prices) do
    with {:ok, product_id} <- positive_integer(conn.params["id"]),
         %Product{} <- Repo.get(Product, product_id, prefix: TenantContext.tenant!()) do
      tenant = TenantContext.tenant!()
      username = conn.assigns.current_scope.user.name
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      result = Repo.transaction(fn -> Enum.map(prices, &upsert_price(&1, product_id, username, now, tenant)) end)
      case result do
        {:ok, entries} -> json(conn, %{entries: Enum.map(entries, &price_response/1)})
        {:error, %Changeset{} = changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: Changeset.traverse_errors(changeset, fn {message, _} -> message end)})
        {:error, _reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "prices are invalid"})
      end
    else
      {:error, :invalid_params} -> conn |> put_status(:bad_request) |> json(%{error: "invalid product id"})
      nil -> conn |> put_status(:not_found) |> json(%{error: "product not found"})
    end
  end
  def set_prices(conn, _), do: conn |> put_status(:bad_request) |> json(%{error: "prices must be a list"})

  defp upsert_price(%{"pricing_id" => pricing_id, "price" => price}, product_id, username, now, tenant) do
    with {:ok, pricing_id} <- positive_integer(pricing_id),
         {price, ""} <- Float.parse(to_string(price)) do
      attrs = %{product_id: product_id, pricing_id: pricing_id, price: price, user_modified: username, date_create: now}
      entry = Repo.one(from(entry in PricingList, where: entry.product_id == ^product_id and entry.pricing_id == ^pricing_id, order_by: [desc: entry.id], limit: 1), prefix: tenant)
      changeset = if entry, do: PricingList.changeset(entry, attrs), else: PricingList.changeset(%PricingList{}, attrs)
      case Repo.insert_or_update(changeset, prefix: tenant) do {:ok, value} -> value; {:error, changeset} -> Repo.rollback(changeset) end
    else
      _ -> Repo.rollback(Changeset.add_error(%PricingList{} |> PricingList.changeset(%{}), :price, "must be a non-negative number"))
    end
  end
  defp upsert_price(_, _product_id, _username, _now, _tenant), do: Repo.rollback(:invalid_prices)
  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_params}
    end
  end
  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp positive_integer(_), do: {:error, :invalid_params}
  defp product_response(product), do: %{id: product.id, name: product.name, cost: product.cost, margin: product.margin, code: product.code, img_path: product.img_path, image_raw: product.image_raw, active: product.active}
  defp price_response(entry), do: %{id: entry.id, product_id: entry.product_id, pricing_id: entry.pricing_id, price: entry.price, date_create: entry.date_create}
end
