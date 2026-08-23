defmodule PosServerWeb.InventoryController do
  use PosServerWeb, :controller

  alias Ecto.Changeset
  alias PosServer.Retaily.{InventoryContext, Orders}

  def index(conn, params) do
    with {:ok, store_id} <- positive_integer(params["store_id"]),
         {:ok, entries} <- inventory_entries(conn.assigns.current_scope, store_id, params["product_ids"]) do
      json(conn, %{entries: entries})
    else
      {:error, :invalid_params} -> conn |> put_status(:bad_request) |> json(%{error: "store_id and product_ids are required"})
      :error -> conn |> put_status(:forbidden) |> json(%{error: "store is not assigned to cashier"})
      {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  defp inventory_entries(scope, store_id, nil), do: InventoryContext.list(scope, store_id)
  defp inventory_entries(scope, store_id, ids) do
    with {:ok, product_ids} <- product_ids(ids) do
      InventoryContext.quantities(scope, store_id, product_ids)
    end
  end

  def adjust(conn, params) do
    case Orders.adjust_inventory(conn.assigns.current_scope, params) do
      {:ok, inventory} ->
        json(conn, %{
          id: inventory.id,
          product_id: inventory.product_id,
          store_id: inventory.store_id,
          prev_quantity: inventory.prev_quantity,
          quantity: inventory.quantity,
          last_update: inventory.last_update,
          user_updated: inventory.user_updated
        })

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Changeset.traverse_errors(changeset, fn {message, _} -> message end)})

      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "inventory or product not found"})
      {:error, :forbidden_store} -> conn |> put_status(:forbidden) |> json(%{error: "store is not assigned to cashier"})
      {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  defp product_ids(value) when is_binary(value) do
    ids = value |> String.split(",", trim: true) |> Enum.map(&positive_integer/1)
    if ids != [] and Enum.all?(ids, &match?({:ok, _}, &1)), do: {:ok, ids |> Enum.map(fn {:ok, id} -> id end) |> Enum.uniq()}, else: {:error, :invalid_params}
  end
  defp product_ids(_), do: {:error, :invalid_params}

  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_params}
    end
  end
  defp positive_integer(_), do: {:error, :invalid_params}
end
