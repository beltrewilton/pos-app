defmodule PosServerWeb.SaleController do
  use PosServerWeb, :controller

  alias Ecto.Changeset
  alias PosServer.Retaily.Sales

  def index(conn, params) do
    case Sales.list_sales(conn.assigns.current_scope, normalize_filters(params)) do
      {:ok, sales} -> json(conn, %{entries: sales})
      {:error, reason} -> error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    case parse_id(id) do
      {:ok, sale_id} ->
        case Sales.get_sale(conn.assigns.current_scope, sale_id) do
          {:ok, sale} -> json(conn, sale)
          {:error, reason} -> error(conn, reason)
        end

      :error -> error(conn, :invalid_id)
    end
  end

  def create(conn, params) do
    case Sales.create_sale(conn.assigns.current_scope, params) do
      {:ok, sale} -> conn |> put_status(:created) |> json(sale)
      {:error, reason} -> error(conn, reason)
    end
  end

  def add_payment(conn, %{"id" => id} = params) do
    with {:ok, sale_id} <- parse_id(id) do
      case Sales.add_payment(conn.assigns.current_scope, sale_id, Map.drop(params, ["id"])) do
        {:ok, sale} -> json(conn, sale)
        {:error, reason} -> error(conn, reason)
      end
    else
      :error -> error(conn, :invalid_id)
    end
  end

  def cancel(conn, %{"id" => id}) do
    with {:ok, sale_id} <- parse_id(id) do
      case Sales.cancel_sale(conn.assigns.current_scope, sale_id) do
        {:ok, sale} -> json(conn, sale)
        {:error, reason} -> error(conn, reason)
      end
    else
      :error -> error(conn, :invalid_id)
    end
  end

  defp normalize_filters(params) do
    Enum.reduce(params, %{}, fn
      {key, value}, acc when key in ["store_id", "client_id"] ->
        case parse_id(value) do
          {:ok, id} -> Map.put(acc, key, id)
          :error -> acc
        end

      {key, value}, acc when key in ["cashier", "invoice_status"] -> Map.put(acc, key, value)
      {key, value}, acc when key in ["date_from", "date_to"] ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, date} -> Map.put(acc, key, date)
          _ -> acc
        end

      _, acc -> acc
    end)
  end

  defp parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}
  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> :error
    end
  end
  defp parse_id(_), do: :error

  defp error(conn, %Changeset{} = changeset), do: conn |> put_status(:unprocessable_entity) |> json(%{errors: Changeset.traverse_errors(changeset, fn {message, _} -> message end)})
  defp error(conn, :unauthorized), do: conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})
  defp error(conn, :not_found), do: conn |> put_status(:not_found) |> json(%{error: "not found"})
  defp error(conn, :forbidden_store), do: conn |> put_status(:forbidden) |> json(%{error: "store is not assigned to cashier"})
  defp error(conn, reason), do: conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
end
