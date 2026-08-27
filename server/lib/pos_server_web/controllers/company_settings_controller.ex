defmodule PosServerWeb.CompanySettingsController do
  use PosServerWeb, :controller

  alias PosServer.Retaily.CompanySettings

  def index(conn, _params), do: respond(conn, CompanySettings.overview(conn.assigns.current_scope))
  def create_price_list(conn, params), do: respond(conn |> put_status(:created), CompanySettings.create_price_list(conn.assigns.current_scope, params))
  def update_price_list(conn, %{"id" => id} = params), do: with_id(conn, id, &CompanySettings.update_price_list(conn.assigns.current_scope, &1, params))
  def delete_price_list(conn, %{"id" => id}), do: with_id(conn, id, &CompanySettings.delete_price_list/1)
  def create_store(conn, params), do: respond(conn |> put_status(:created), CompanySettings.create_store(conn.assigns.current_scope, params))
  def update_store(conn, %{"id" => id} = params), do: with_id(conn, id, &CompanySettings.update_store(conn.assigns.current_scope, &1, params))
  def delete_store(conn, %{"id" => id}), do: with_id(conn, id, &CompanySettings.delete_store/1)

  defp respond(conn, {:ok, value}), do: json(conn, value)
  defp respond(conn, {:error, :not_found}), do: conn |> put_status(:not_found) |> json(%{error: "not found"})
  defp respond(conn, {:error, %Ecto.Changeset{} = changeset}), do: conn |> put_status(:unprocessable_entity) |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _} -> message end)})
  defp respond(conn, {:error, _}), do: conn |> put_status(:unprocessable_entity) |> json(%{error: "This item cannot be deleted while it is in use."})
  defp with_id(conn, id, fun) do
    case Integer.parse(id) do
      {value, ""} when value > 0 -> respond(conn, fun.(value))
      _ -> conn |> put_status(:bad_request) |> json(%{error: "invalid id"})
    end
  end
end
