defmodule PosServerWeb.ProductController do
  use PosServerWeb, :controller

  alias PosServer.Retaily.Sql

  @page_size 100

  def index(conn, params) do
    with {:ok, cursor} <- parse_cursor(params["cursor"]),
         {:ok, page} <- Sql.active_products_page(cursor, limit: @page_size) do
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
        |> json(%{error: "could not load products", details: inspect(reason)})
    end
  end

  defp parse_cursor(nil), do: {:ok, nil}

  defp parse_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, :invalid_cursor}
    end
  end
end
