defmodule PosServerWeb.CustomerControllerTest do
  use PosServerWeb.ConnCase, async: false

  alias PosServer.Accounts
  alias PosServer.Repo
  alias PosServer.Retaily.Client

  @tenant "sales_seed_test"
  @prefix "sales_seed_test"

  setup do
    Process.delete(:current_tenant)

    Enum.each([{30_218, "EXISTING CUSTOMER"}, {30_219, "OLDER CUSTOMER"}, {30_220, "MARIA CUSTOMER"}], fn {id, name} ->
      Repo.insert!(%Client{id: id, name: name, celphone: if(id == 30_220, do: "809-555-0199", else: nil)}, prefix: @prefix)
    end)

    {:ok, token} = token_for("walex")
    %{walex_conn: authenticated_conn(token)}
  end

  test "lists the most recently registered customers and filters by name or phone", %{walex_conn: conn} do
    customers = conn |> get(~p"/api/customers") |> json_response(:ok)
    assert Enum.take(Enum.map(customers["entries"], & &1["id"]), 2) == [30_220, 30_219]

    assert authenticated_conn_for("walex")
           |> get(~p"/api/customers?search=MARIA")
           |> json_response(:ok)
           |> Map.fetch!("entries")
           |> Enum.map(& &1["id"]) == [30_220]

    assert authenticated_conn_for("walex")
           |> get(~p"/api/customers?search=0199")
           |> json_response(:ok)
           |> Map.fetch!("entries")
           |> Enum.map(& &1["id"]) == [30_220]
  end

  defp token_for(name) do
    {:ok, user} =
      Accounts.create_user(%{
        "name" => name,
        "email" => "#{name}-#{System.unique_integer([:positive])}@example.test",
        "tenant" => @tenant,
        "password" => "a-long-test-password"
      })

    {:ok, token} = Accounts.create_user_token(%{"user_id" => user.id})
    {:ok, Accounts.encode_session_token(token)}
  end

  defp authenticated_conn_for(name) do
    {:ok, token} = token_for(name)
    authenticated_conn(token)
  end

  defp authenticated_conn(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")
end
