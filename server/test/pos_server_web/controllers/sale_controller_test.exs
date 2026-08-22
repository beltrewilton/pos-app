defmodule PosServerWeb.SaleControllerTest do
  use PosServerWeb.ConnCase, async: false

  import Ecto.Query

  alias PosServer.Accounts
  alias PosServer.Repo
  alias PosServer.Retaily.{Client, Inventory, Product, Sale, SaleLine, SalePaid, Sequence, Store, User, UserStore}

  @tenant "sales_seed_test"
  @prefix "sales_seed_test"
  @other_tenant "sales_other_test"
  @other_prefix "sales_other_test"

  setup do
    Process.delete(:current_tenant)
    seed_retaily_rows()
    Repo.insert!(%User{id: 1, username: "walex", is_active: 1}, prefix: @other_prefix)

    {:ok, walex_token} = token_for("walex")
    {:ok, no_store_token} = token_for("no_store")
    {:ok, other_tenant_token} = token_for("walex", @other_tenant)

    %{
      walex_conn: authenticated_conn(walex_token),
      no_store_conn: authenticated_conn(no_store_token),
      other_tenant_conn: authenticated_conn(other_tenant_token)
    }
  end

  test "creates the paid discounted delivery sale from 363886", %{walex_conn: conn} do
    sale = create_delivery_sale(conn)

    assert sale["invoice_status"] == "close"
    assert sale["due_balance"] in ["0", "0.00"]
    assert inventory_quantity(19_463) == 11
    assert Repo.aggregate(from(line in SaleLine, where: line.sale_id == ^sale["id"]), :count, prefix: @prefix) == 1
    assert Repo.aggregate(from(payment in SalePaid, where: payment.sale_id == ^sale["id"]), :count, prefix: @prefix) == 1

    header = Repo.get!(Sale, sale["id"], prefix: @prefix)
    assert header.amount == Decimal.new("3290.00")
    assert header.discount == Decimal.new("110.00")
    assert header.delivery_charge == Decimal.new("200.00")
  end

  test "creates, pays, and closes the credit sale from 363873", %{walex_conn: conn} do
    response =
      conn
      |> post(~p"/api/sales", credit_sale_payload())
      |> json_response(:created)

    sale_id = response["id"]
    assert response["invoice_status"] == "open"
    assert Repo.aggregate(from(payment in SalePaid, where: payment.sale_id == ^sale_id), :count, prefix: @prefix) == 0
    assert inventory_quantity(19_203) == 264

    paid =
      authenticated_conn_for("walex")
      |> post(~p"/api/sales/#{sale_id}/payments", %{amount: "200", type: "CASH"})
      |> json_response(:ok)

    assert paid["invoice_status"] == "close"
    assert paid["due_balance"] in ["0", "0.00"]
  end

  test "derives totals for the multiple-line sale from 363885", %{walex_conn: conn} do
    response =
      conn
      |> post(~p"/api/sales", multiple_line_sale_payload())
      |> json_response(:created)

    assert response["invoice_status"] == "close"

    sale = Repo.get!(Sale, response["id"], prefix: @prefix)
    assert sale.amount == Decimal.new("1830.00")
    assert sale.discount == Decimal.new("200.00")
    assert Repo.aggregate(from(line in SaleLine, where: line.sale_id == ^sale.id), :count, prefix: @prefix) == 2
  end

  test "cancellation is idempotent and restores stock", %{walex_conn: conn} do
    sale = create_delivery_sale(conn)

    cancelled =
      authenticated_conn_for("walex")
      |> post(~p"/api/sales/#{sale["id"]}/cancel")
      |> json_response(:ok)

    assert cancelled["status"] == "RETURN"
    assert cancelled["invoice_status"] == "cancelled"
    assert inventory_quantity(19_463) == 12

    again =
      authenticated_conn_for("walex")
      |> post(~p"/api/sales/#{sale["id"]}/cancel")
      |> json_response(:ok)

    assert again["id"] == sale["id"]
    assert inventory_quantity(19_463) == 12
    assert Repo.aggregate(from(line in SaleLine, where: line.sale_id == ^sale["id"]), :count, prefix: @prefix) == 1
    assert Repo.aggregate(from(payment in SalePaid, where: payment.sale_id == ^sale["id"]), :count, prefix: @prefix) == 1
  end

  test "insufficient stock rolls back the sequence and every sale write", %{walex_conn: conn} do
    before_sequence = Repo.get_by!(Sequence, [code: "DV"], prefix: @prefix).current_seq

    response =
      conn
      |> post(~p"/api/sales", delivery_sale_payload(%{lines: [%{product_id: 19_463, quantity: 13, discount: "0"}]}))
      |> json_response(:unprocessable_entity)

    assert response["error"] == "insufficient_stock"
    assert Repo.get_by!(Sequence, [code: "DV"], prefix: @prefix).current_seq == before_sequence
    assert inventory_quantity(19_463) == 12
    assert Repo.aggregate(Sale, :count, prefix: @prefix) == 0
    assert Repo.aggregate(SaleLine, :count, prefix: @prefix) == 0
    assert Repo.aggregate(SalePaid, :count, prefix: @prefix) == 0

    negative =
      authenticated_conn_for("walex")
      |> post(~p"/api/sales", delivery_sale_payload(%{lines: [%{product_id: 19_385, quantity: 1, discount: "0"}]}))
      |> json_response(:unprocessable_entity)

    assert negative["error"] == "insufficient_stock"
    assert inventory_quantity(19_385) == -144
  end

  test "requires a tenant scope and enforces tenant and assigned-store isolation", %{no_store_conn: no_store_conn, other_tenant_conn: other_tenant_conn} do
    assert build_conn() |> get(~p"/api/sales") |> response(:unauthorized)

    assert no_store_conn
           |> post(~p"/api/sales", delivery_sale_payload())
           |> response(:forbidden)

    assert no_store_conn |> get(~p"/api/sales?store_id=2") |> json_response(:ok) == %{"entries" => []}
    assert other_tenant_conn |> get(~p"/api/sales") |> json_response(:ok) == %{"entries" => []}
  end

  defp create_delivery_sale(conn) do
    conn
    |> post(~p"/api/sales", delivery_sale_payload())
    |> json_response(:created)
  end

  defp delivery_sale_payload(overrides \\ %{}) do
    Map.merge(
      %{
        store_id: 2,
        client_id: 30_218,
        sequence_type: "DV",
        status: "CASH",
        sale_type: "FOR_DELIVER",
        delivery_charge: "200",
        lines: [%{product_id: 19_463, quantity: 1, discount: "110"}],
        payments: [%{amount: "3290", type: "CASH"}]
      },
      overrides
    )
  end

  defp credit_sale_payload do
    %{store_id: 2, client_id: 26_623, sequence_type: "CF", status: "CREDIT", sale_type: "IN_SHOP", delivery_charge: "0", lines: [%{product_id: 19_203, quantity: 1, discount: "40"}], payments: []}
  end

  defp multiple_line_sale_payload do
    %{store_id: 2, client_id: 24_181, sequence_type: "CF", status: "CASH", sale_type: "IN_SHOP", delivery_charge: "0", lines: [%{product_id: 8_679, quantity: 1, discount: "200"}, %{product_id: 19_383, quantity: 1, discount: "0"}], payments: [%{amount: "1830", type: "CASH"}]}
  end

  defp seed_retaily_rows do
    prefix = @prefix
    Repo.insert!(%Store{id: 2, name: "SEED STORE"}, prefix: prefix)
    walex = Repo.insert!(%User{id: 1, username: "walex", is_active: 1}, prefix: prefix)
    no_store = Repo.insert!(%User{id: 2, username: "no_store", is_active: 1}, prefix: prefix)
    Repo.insert!(%UserStore{user_id: walex.id, store_id: 2}, prefix: prefix)
    _ = no_store

    Enum.each([{26_623, "CREDIT CLIENT"}, {24_181, "MULTI LINE CLIENT"}, {30_218, "SCOLNY REYES"}], fn {id, name} ->
      Repo.insert!(%Client{id: id, name: name}, prefix: prefix)
    end)

    Enum.each([
      {8_679, 1800, 10},
      {19_203, 240, 265},
      {19_383, 230, 10},
      {19_385, 300, -144},
      {19_463, 3200, 12}
    ], fn {id, price, quantity} ->
      Repo.insert!(%Product{id: id, name: "SEED #{id}", price: price * 1.0, active: 1}, prefix: prefix)
      Repo.insert!(%Inventory{product_id: id, store_id: 2, prev_quantity: quantity, quantity: quantity, next_quantity: quantity}, prefix: prefix)
    end)

    Repo.insert!(%Sequence{id: 1, name: "CONSUMIDOR FINAL", code: "CF", prefix: "B02", fill: 6, increment_by: 1, current_seq: 35_700}, prefix: prefix)
    Repo.insert!(%Sequence{id: 3, name: "DIARIO DE VENTAS", code: "DV", prefix: "VEN", fill: 9, increment_by: 1, current_seq: 24_897}, prefix: prefix)
  end

  defp token_for(name, tenant \\ @tenant) do
    {:ok, user} = Accounts.create_user(%{"name" => name, "email" => "#{name}-#{System.unique_integer([:positive])}@example.test", "tenant" => tenant, "password" => "a-long-test-password"})
    {:ok, token} = Accounts.create_user_token(%{"user_id" => user.id})
    {:ok, Accounts.encode_session_token(token)}
  end

  defp authenticated_conn_for(name) do
    {:ok, token} = token_for(name)
    authenticated_conn(token)
  end

  defp authenticated_conn(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  defp inventory_quantity(product_id), do: Repo.get_by!(Inventory, [product_id: product_id, store_id: 2], prefix: @prefix).quantity
end
