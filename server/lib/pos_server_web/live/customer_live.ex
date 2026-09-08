defmodule PosServerWeb.CustomerLive do
  @moduledoc false
  use PosServerWeb, :live_view

  import PosServerWeb.CustomerComponents
  import PosServerWeb.PosLayoutComponents

  alias Ecto.Changeset
  alias PosServer.{Authentication, Repo, TenantContext}
  alias PosServer.Accounts.Scope
  alias PosServer.Retaily.{Client, InventoryContext, Sales, Sql}

  @page_size 100

  @impl true
  def mount(_params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, scope} <- Authentication.authenticate(token),
         true <- customer_access?(scope),
         _ <- TenantContext.put_tenant(scope.tenant),
         {:ok, stores} <- InventoryContext.stores(scope),
         %{id: store_id} <- selected_store(stores, session["store_id"]) do
      {:ok,
       socket
       |> assign(:page_title, "Tigoo Customers")
       |> assign(:scope, scope)
       |> assign(:stores, stores)
       |> assign(:store_id, store_id)
       |> assign(:customers, [])
       |> assign(:customer_search, "")
       |> assign(:customers_status, "Loading customers…")
       |> assign(:loading_customers?, true)
       |> assign(:mode, :list)
       |> assign(:detail, nil)
       |> assign(:detail_loading?, false)
       |> assign(:customer_dialog?, false)
       |> assign(:customer_form_status, "")
       |> assign(:saving_customer?, false)
       |> load_customers()}
    else
      _ -> {:ok, socket |> put_flash(:error, "Customer access is required.") |> redirect(to: ~p"/pos/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.pos_layout id="customer-live" class="pos-shell invoice-view" active_page={:customers} scope={@scope} stores={@stores} store_id={@store_id} phx-hook="CustomerScreen" data-view={@mode}>
      <section class="catalog-panel" data-view={if @mode == :detail, do: "customer-detail", else: "customers"}>
        <.customer_list :if={@mode == :list} customers={@customers} search={@customer_search} status={@customers_status} loading={@loading_customers?} />
        <.customer_detail :if={@mode == :detail} detail={@detail} loading={@detail_loading?} />
      </section>
      <.customer_dialog :if={@customer_dialog?} status={@customer_form_status} saving={@saving_customer?} />
    </.pos_layout>
    """
  end

  @impl true
  def handle_event("change_store", %{"store_id" => id}, socket) do
    with {store_id, ""} <- Integer.parse(id),
         true <- Enum.any?(socket.assigns.stores, &(&1.id == store_id)),
         {:ok, _} <- InventoryContext.authorize_store(socket.assigns.scope, store_id) do
      {:noreply,
       socket
       |> assign(:store_id, store_id)
       |> assign(:mode, :list)
       |> assign(:detail, nil)
       |> assign(:loading_customers?, true)
       |> assign(:customers_status, "Loading customers…")
       |> load_customers()}
    else
      _ -> {:noreply, put_flash(socket, :error, "The selected store is unavailable.")}
    end
  end

  def handle_event("search_customers", %{"value" => value}, socket) do
    {:noreply,
     socket
     |> assign(:customer_search, value)
     |> assign(:loading_customers?, true)
     |> assign(:customers_status, "Loading customers…")
     |> load_customers()}
  end

  def handle_event("open_customer_dialog", _, socket), do: {:noreply, socket |> assign(:customer_dialog?, true) |> assign(:customer_form_status, "")}
  def handle_event("close_customer_dialog", _, socket), do: {:noreply, socket |> assign(:customer_dialog?, false) |> assign(:customer_form_status, "") |> assign(:saving_customer?, false)}

  def handle_event("create_customer", params, socket) do
    tenant = TenantContext.tenant!()
    attrs = params |> Map.put("wholesaler", wholesaler_value(params["is_wholesaler"])) |> Map.delete("is_wholesaler")

    case %Client{} |> Client.changeset(attrs) |> Repo.insert(prefix: tenant) do
      {:ok, customer} ->
        {:noreply,
         socket
         |> assign(:customer_dialog?, false)
         |> assign(:customer_form_status, "")
         |> assign(:saving_customer?, false)
         |> load_customers()
         |> open_detail(customer.id)}

      {:error, %Changeset{}} ->
        {:noreply, socket |> assign(:customer_form_status, "Could not create customer. Check the data and try again.") |> assign(:saving_customer?, false)}
    end
  end

  def handle_event("open_customer_detail", %{"id" => id}, socket), do: {:noreply, open_detail(socket, integer(id))}
  def handle_event("close_customer_detail", _, socket), do: {:noreply, socket |> assign(:mode, :list) |> assign(:detail, nil) |> push_event("customer:list-restored", %{})}

  defp load_customers(socket) do
    case Sql.recent_clients_page(nil, socket.assigns.customer_search, limit: @page_size) do
      {:ok, page} ->
        customers = Enum.map(page.entries, &normalize_customer/1)
        status = if customers == [], do: "No customers found.", else: ""
        socket |> assign(:customers, customers) |> assign(:loading_customers?, false) |> assign(:customers_status, status)

      _ ->
        socket |> assign(:customers, []) |> assign(:loading_customers?, false) |> assign(:customers_status, "Could not load customers. Check the server connection.")
    end
  end

  defp open_detail(socket, id) do
    socket = socket |> assign(:mode, :detail) |> assign(:detail, nil) |> assign(:detail_loading?, true) |> push_event("customer:detail-opened", %{})

    case Sales.customer_detail(socket.assigns.scope, id) do
      {:ok, detail} -> socket |> assign(:detail, normalize_detail(detail)) |> assign(:detail_loading?, false)
      {:error, reason} -> socket |> assign(:detail_loading?, false) |> put_flash(:error, "Customer details could not be loaded: #{reason}")
    end
  end

  defp normalize_customer(customer) do
    %{
      id: value(customer, :id),
      name: value(customer, :name),
      document_id: value(customer, :document_id),
      celphone: value(customer, :celphone),
      email: value(customer, :email),
      wholesaler: value(customer, :wholesaler),
      pending_balance: value(customer, :pending_balance),
      last_purchase_date: value(customer, :last_purchase_date)
    }
  end

  defp normalize_detail(detail) do
    %{
      customer: normalize_detail_customer(value(detail, :customer)),
      summary: value(detail, :summary) || %{},
      purchases: value(detail, :purchases) || []
    }
  end

  defp normalize_detail_customer(customer) do
    %{
      id: value(customer, :id),
      name: value(customer, :name),
      document_id: value(customer, :document_id),
      address: value(customer, :address),
      celphone: value(customer, :celphone),
      email: value(customer, :email),
      date_create: value(customer, :date_create),
      wholesaler: value(customer, :wholesaler)
    }
  end

  defp selected_store(stores, selected_id) do
    case Integer.parse(to_string(selected_id || "")) do
      {id, ""} -> Enum.find(stores, List.first(stores), &(&1.id == id))
      _ -> List.first(stores)
    end
  end

  defp integer(value) when is_integer(value), do: value
  defp integer(value) do
    case Integer.parse(to_string(value || "")) do
      {number, _} -> number
      _ -> 0
    end
  end
  defp value(nil, _key), do: nil
  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp wholesaler_value(value) when value in [true, 1, "1", "true", "on"], do: 1
  defp wholesaler_value(_), do: 0
  defp customer_access?(scope), do: Scope.allowed?(scope, "sales.view") or Scope.allowed?(scope, "sales.pos")
end
