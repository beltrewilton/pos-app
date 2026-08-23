defmodule PosServerWeb.CustomerController do
  use PosServerWeb, :controller

  alias Ecto.Changeset
  alias PosServer.{Repo, TenantContext}
  alias PosServer.Retaily.{Client, Sql}

  @page_size 100

  def index(conn, params) do
    with {:ok, cursor} <- parse_cursor(params["cursor"]),
         {:ok, page} <- Sql.recent_clients_page(cursor, params["search"], limit: @page_size) do
      json(conn, %{
        entries: page.entries,
        has_more: page.has_more?,
        next_cursor: page.next_cursor
      })
    else
      {:error, :invalid_cursor} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "cursor must be a non-negative integer"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "could not load customers", details: inspect(reason)})
    end
  end

  def create(conn, params) do
    tenant = TenantContext.tenant!()

    case %Client{} |> Client.changeset(params) |> Repo.insert(prefix: tenant) do
      {:ok, client} -> conn |> put_status(:created) |> json(customer_response(client))

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Changeset.traverse_errors(changeset, fn {message, _} -> message end)})
    end
  end

  defp parse_cursor(nil), do: {:ok, nil}

  defp parse_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, :invalid_cursor}
    end
  end

  defp customer_response(client) do
    %{
      id: client.id,
      name: client.name,
      document_id: client.document_id,
      address: client.address,
      celphone: client.celphone,
      email: client.email,
      date_create: client.date_create,
      wholesaler: client.wholesaler
    }
  end
end
