defmodule PosServerWeb.AdminSessionController do
  use PosServerWeb, :controller

  alias PosServer.AdminAuthentication

  def new(conn, _params) do
    if get_session(conn, :admin_authenticated) == true do
      redirect(conn, to: ~p"/admin")
    else
      render(conn, :new)
    end
  end

  def create(conn, %{"admin" => %{"username" => username, "password" => password}}) do
    case AdminAuthentication.authenticate(username, password) do
      :ok ->
        conn
        |> put_session(:admin_authenticated, true)
        |> redirect(to: ~p"/admin")

      :error ->
        conn
        |> put_flash(:error, "Invalid username or password.")
        |> redirect(to: ~p"/admin/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid username or password.")
    |> redirect(to: ~p"/admin/login")
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:admin_authenticated)
    |> redirect(to: ~p"/admin/login")
  end
end
