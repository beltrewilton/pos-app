defmodule PosServerWeb.InventoryController do
  use PosServerWeb, :controller

  alias PosServer.Retaily.InventoryContext

  def index(conn, params) do
    with {:ok, store_id} <- positive_integer(params["store_id"]),
         {:ok, product_ids} <- product_ids(params["product_ids"]),
         {:ok, entries} <- InventoryContext.quantities(conn.assigns.current_scope, store_id, product_ids) do
      json(conn, %{entries: entries})
    else
      {:error, :invalid_params} -> conn |> put_status(:bad_request) |> json(%{error: "store_id and product_ids are required"})
      :error -> conn |> put_status(:forbidden) |> json(%{error: "store is not assigned to cashier"})
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
