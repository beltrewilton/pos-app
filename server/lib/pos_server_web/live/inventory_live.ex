defmodule PosServerWeb.InventoryLive do
  @moduledoc false
  use PosServerWeb, :live_view

  import PosServerWeb.PosLayoutComponents

  alias PosServer.{Authentication, InventoryEvents, TenantContext}
  alias PosServer.Accounts.Scope
  alias PosServer.Retaily.{InventoryContext, Orders, ProductCatalog, Sql}

  @sort_keys ~w(product_name product_code product_cost product_price total_quantity quantity prev_quantity last_update user_updated)

  @impl true
  def mount(_params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, scope} <- Authentication.authenticate(token),
         true <- Scope.allowed?(scope, "inventory.view"),
         _ <- TenantContext.put_tenant(scope.tenant),
         {:ok, stores} <- InventoryContext.stores(scope),
         %{id: store_id} <- selected_store(stores, session["store_id"]) do
      socket =
        socket
        |> assign(:page_title, "Tigoo Inventory")
        |> assign(:scope, scope)
        |> assign(:stores, stores)
        |> assign(:store_id, store_id)
        |> assign(:entries, [])
        |> assign(:summary, nil)
        |> assign(:kpis_expanded, false)
        |> assign(:search, "")
        |> assign(:show_archived?, false)
        |> assign(:filter, "")
        |> assign(:sort, %{key: "last_update", direction: :desc})
        |> assign(:expanded, nil)
        |> assign(:store_quantities, [])
        |> assign(:traces, [])
        |> assign(:editing_product_id, nil)
        |> assign(:locally_updated_product_ids, MapSet.new())
        |> assign(:product_dialog, false)
        |> assign(:editing_product, nil)
        |> assign(:product_form_status, "")
        |> assign(:pricing_lists, ProductCatalog.pricing_lists(scope))
        |> assign(:status, "Loading inventory…")
        |> assign(:loading?, true)
        |> load_inventory()

      if connected?(socket), do: InventoryEvents.subscribe(scope.tenant, store_id)
      {:ok, socket}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Inventory access is required.")
         |> redirect(to: ~p"/pos/login")}
    end
  end

  @impl true
  def handle_event("change_store", %{"store_id" => id}, socket) do
    with {store_id, ""} <- Integer.parse(id),
         true <- Enum.any?(socket.assigns.stores, &(&1.id == store_id)),
         {:ok, _} <- InventoryContext.authorize_store(socket.assigns.scope, store_id) do
      InventoryEvents.unsubscribe(socket.assigns.scope.tenant, socket.assigns.store_id)
      InventoryEvents.subscribe(socket.assigns.scope.tenant, store_id)

      {:noreply,
       socket
       |> assign(:store_id, store_id)
       |> clear_row_context()
       |> assign(:loading?, true)
       |> assign(:status, "Loading inventory…")
       |> load_inventory()}
    else
      _ -> {:noreply, put_flash(socket, :error, "The selected store is unavailable.")}
    end
  end

  def handle_event("search", %{"value" => value}, socket),
    do: {:noreply, assign(socket, :search, value)}

  def handle_event("toggle_archived", _, socket) do
    {:noreply,
     socket
     |> assign(:show_archived?, !socket.assigns.show_archived?)
     |> clear_row_context()
     |> assign(:loading?, true)
     |> load_inventory()}
  end

  def handle_event("sort", %{"key" => key}, socket) when key in @sort_keys do
    sort =
      if socket.assigns.sort.key == key,
        do: %{key: key, direction: flip(socket.assigns.sort.direction)},
        else: %{key: key, direction: :asc}

    {:noreply, socket |> assign(:sort, sort) |> update(:entries, &sort_entries(&1, sort))}
  end

  def handle_event("toggle_filter", %{"filter" => filter}, socket)
      when filter in ["negative", "uncosted"] do
    filter = if socket.assigns.filter == filter, do: "", else: filter

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> clear_row_context()
     |> assign(:loading?, true)
     |> load_inventory()}
  end

  def handle_event("toggle_kpis", _, socket),
    do: {:noreply, assign(socket, :kpis_expanded, !socket.assigns.kpis_expanded)}

  def handle_event("open_product_dialog", _, socket),
    do:
      {:noreply,
       socket
       |> assign(:product_dialog, true)
       |> assign(:editing_product, nil)
       |> assign(:product_form_status, "")}

  def handle_event("close_product_dialog", _, socket),
    do:
      {:noreply,
       socket
       |> assign(:product_dialog, false)
       |> assign(:editing_product, nil)
       |> assign(:product_form_status, "")}

  def handle_event("open_product_editor", %{"product_id" => id}, socket) do
    case ProductCatalog.get(socket.assigns.scope, integer(id)) do
      {:ok, product} ->
        {:noreply,
         socket
         |> assign(:product_dialog, true)
         |> assign(:editing_product, product)
         |> assign(:product_form_status, "")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You do not have permission to edit products.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Product could not be loaded.")}
    end
  end

  def handle_event("create_product", params, socket) do
    case ProductCatalog.create(socket.assigns.scope, product_attrs(params, socket)) do
      {:ok, product} ->
        socket =
          socket
          |> assign(:product_dialog, false)
          |> assign(:product_form_status, "")
          |> put_flash(:info, "Product created.")
          |> load_inventory()

        {:noreply, socket |> ignore_next_inventory_event(product.id)}

      {:error, :forbidden} ->
        {:noreply,
         assign(socket, :product_form_status, "You do not have permission to create products.")}

      {:error, :default_price_required} ->
        {:noreply, assign(socket, :product_form_status, "A default selling price is required.")}

      {:error, _} ->
        {:noreply,
         assign(
           socket,
           :product_form_status,
           "Product could not be created. Check the required fields."
         )}
    end
  end

  def handle_event("update_product", params, %{assigns: %{editing_product: product}} = socket)
      when not is_nil(product) do
    case ProductCatalog.update(socket.assigns.scope, product.id, product_attrs(params, socket)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:product_dialog, false)
         |> assign(:editing_product, nil)
         |> put_flash(:info, "Product updated.")
         |> load_inventory()}

      {:error, :forbidden} ->
        {:noreply,
         assign(socket, :product_form_status, "You do not have permission to edit products.")}

      {:error, :default_price_required} ->
        {:noreply, assign(socket, :product_form_status, "A default selling price is required.")}

      {:error, _} ->
        {:noreply,
         assign(
           socket,
           :product_form_status,
           "Product could not be updated. Check the required fields."
         )}
    end
  end

  def handle_event("set_product_status", %{"product_id" => id, "status" => status}, socket)
      when status in ["active", "archived"] do
    product_id = integer(id)
    entry = Enum.find(socket.assigns.entries, &(&1.product_id == product_id))

    attrs =
      case status do
        "active" ->
          %{store_id: socket.assigns.store_id, active: !product_active?(entry)}

        "archived" ->
          %{store_id: socket.assigns.store_id, archived: !product_archived?(entry)}
      end

    case ProductCatalog.update_status(socket.assigns.scope, product_id, attrs) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product status updated.")
         |> load_inventory()}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You do not have permission to edit products.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Product status could not be updated.")}
    end
  end

  def handle_event("toggle_quantities", %{"product_id" => id}, socket) do
    product_id = integer(id)

    if socket.assigns.expanded == {:quantities, product_id} do
      {:noreply, clear_row_context(socket)}
    else
      case InventoryContext.product_store_quantities(
             socket.assigns.scope,
             socket.assigns.store_id,
             product_id
           ) do
        {:ok, entries} ->
          {:noreply,
           socket
           |> clear_row_context()
           |> assign(:expanded, {:quantities, product_id})
           |> assign(:store_quantities, entries)}

        _ ->
          {:noreply, put_flash(socket, :error, "Store quantities could not be loaded.")}
      end
    end
  end

  def handle_event("toggle_traces", %{"product_id" => id}, socket) do
    product_id = integer(id)

    if socket.assigns.expanded == {:traces, product_id} do
      {:noreply, clear_row_context(socket)}
    else
      case InventoryContext.product_traces(
             socket.assigns.scope,
             socket.assigns.store_id,
             product_id
           ) do
        {:ok, entries} ->
          {:noreply,
           socket
           |> clear_row_context()
           |> assign(:expanded, {:traces, product_id})
           |> assign(:traces, entries)}

        _ ->
          {:noreply, put_flash(socket, :error, "Product history could not be loaded.")}
      end
    end
  end

  def handle_event("edit_quantity", %{"product_id" => id}, socket),
    do: {:noreply, assign(socket, :editing_product_id, integer(id))}

  def handle_event("cancel_edit", _, socket),
    do: {:noreply, assign(socket, :editing_product_id, nil)}

  def handle_event("save_quantity", %{"product_id" => id, "quantity" => value}, socket) do
    product_id = integer(id)

    with true <- Scope.allowed?(socket.assigns.scope, "inventory.stores"),
         %{quantity: current} <-
           Enum.find(socket.assigns.entries, &(&1.product_id == product_id)),
         {quantity, ""} <- Integer.parse(value),
         {:ok, updated} <-
           Orders.adjust_inventory(socket.assigns.scope, %{
             "product_id" => product_id,
             "store_id" => socket.assigns.store_id,
             "quantity" => quantity - current
           }) do
      {:noreply,
       socket
       |> apply_current_store_update(product_id, updated)
       |> ignore_next_inventory_event(product_id)
       |> assign(:editing_product_id, nil)
       |> put_flash(:info, "Inventory updated.")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "You do not have permission to update inventory.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Enter a whole-number quantity.")}
    end
  end

  def handle_event(
        "save_store_quantity",
        %{"product_id" => product_id, "store_id" => store_id, "quantity" => value},
        socket
      ) do
    product_id = integer(product_id)
    store_id = integer(store_id)

    with true <- Scope.allowed?(socket.assigns.scope, "inventory.stores"),
         %{quantity: current} <-
           Enum.find(socket.assigns.store_quantities, &(&1.store_id == store_id)),
         {quantity, ""} <- Integer.parse(value),
         {:ok, updated} <-
           Orders.adjust_inventory(socket.assigns.scope, %{
             "product_id" => product_id,
             "store_id" => store_id,
             "quantity" => quantity - current
           }) do
      {:noreply,
       socket
       |> apply_store_update(product_id, store_id, current, updated)
       |> ignore_next_inventory_event(product_id)
       |> put_flash(:info, "Inventory updated.")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "You do not have permission to update inventory.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Enter a whole-number quantity.")}
    end
  end

  @impl true
  def handle_info({:inventory_changed, %{product_ids: product_ids}}, socket) do
    changed = MapSet.new(product_ids)

    if MapSet.subset?(changed, socket.assigns.locally_updated_product_ids) do
      {:noreply, update(socket, :locally_updated_product_ids, &MapSet.difference(&1, changed))}
    else
      {:noreply, load_inventory(socket)}
    end
  end

  defp load_inventory(socket) do
    filter = if socket.assigns.filter == "", do: nil, else: socket.assigns.filter

    case {InventoryContext.list(socket.assigns.scope, socket.assigns.store_id, filter,
            include_archived?: socket.assigns.show_archived?
          ),
          Sql.inventory_summary(socket.assigns.store_id)} do
      {{:ok, entries}, {:ok, summary}} ->
        entries = sort_entries(entries, socket.assigns.sort)

        socket
        |> assign(:entries, entries)
        |> assign(:summary, summary)
        |> assign(:loading?, false)
        |> assign(:status, inventory_status(entries))

      _ ->
        socket |> assign(:loading?, false) |> assign(:status, "Inventory could not be loaded.")
    end
  end

  # Quantity writes deliberately patch only the affected assigns. In particular,
  # do not call load_inventory/1 here: the Tauri UI keeps an edited row in its
  # current visual position even when the active sort is "Last updated".
  defp apply_current_store_update(socket, product_id, updated) do
    update(socket, :entries, fn entries ->
      Enum.map(entries, fn entry ->
        if entry.product_id == product_id do
          quantity = value(updated, :quantity)

          total_quantity =
            (entry.total_quantity || entry.quantity || 0) + max(quantity, 0) -
              max(entry.quantity || 0, 0)

          Map.merge(entry, %{
            quantity: quantity,
            total_quantity: total_quantity,
            prev_quantity: value(updated, :prev_quantity),
            last_update: value(updated, :last_update),
            user_updated: value(updated, :user_updated)
          })
        else
          entry
        end
      end)
    end)
  end

  defp apply_store_update(socket, product_id, store_id, previous_quantity, updated) do
    socket =
      update(socket, :store_quantities, fn entries ->
        Enum.map(entries, fn entry ->
          if entry.store_id == store_id do
            Map.merge(entry, %{
              quantity: value(updated, :quantity),
              prev_quantity: value(updated, :prev_quantity),
              last_update: value(updated, :last_update),
              user_updated: value(updated, :user_updated)
            })
          else
            entry
          end
        end)
      end)

    if store_id == socket.assigns.store_id do
      apply_current_store_update(socket, product_id, updated)
    else
      delta = max(value(updated, :quantity) || 0, 0) - max(previous_quantity || 0, 0)

      update(socket, :entries, fn entries ->
        Enum.map(entries, fn entry ->
          if entry.product_id == product_id,
            do:
              Map.put(
                entry,
                :total_quantity,
                (entry.total_quantity || entry.quantity || 0) + delta
              ),
            else: entry
        end)
      end)
    end
  end

  defp clear_row_context(socket),
    do:
      socket
      |> assign(:expanded, nil)
      |> assign(:store_quantities, [])
      |> assign(:traces, [])
      |> assign(:editing_product_id, nil)

  defp ignore_next_inventory_event(socket, product_id),
    do: update(socket, :locally_updated_product_ids, &MapSet.put(&1, product_id))

  defp flip(:asc), do: :desc
  defp flip(:desc), do: :asc
  defp integer(value) when is_integer(value), do: value

  defp integer(value) do
    case Integer.parse(to_string(value)) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp product_attrs(params, socket) do
    prices =
      params
      |> Map.get("prices", %{})
      |> Enum.flat_map(fn {pricing_id, price} ->
        case Float.parse(to_string(price)) do
          {amount, ""} when amount >= 0 -> [%{pricing_id: integer(pricing_id), price: amount}]
          _ -> []
        end
      end)

    %{
      store_id: socket.assigns.store_id,
      name: params |> Map.get("name", "") |> String.trim(),
      code: params |> Map.get("code", "") |> String.trim(),
      cost: decimal(Map.get(params, "cost")),
      image_raw: Map.get(params, "image_raw") || nil,
      active: checkbox?(Map.get(params, "active")),
      archived: checkbox?(Map.get(params, "archived")),
      prices: prices
    }
  end

  defp checkbox?(value) when value in [true, "true", "1", "on"], do: true
  defp checkbox?(_), do: false

  defp inventory_status(entries),
    do: if(entries == [], do: "No inventory found.", else: "#{length(entries)} products")

  defp visible_entries(assigns) do
    query = assigns.search |> String.trim() |> String.downcase()

    if query == "",
      do: assigns.entries,
      else:
        Enum.filter(assigns.entries, fn e ->
          String.contains?(
            String.downcase("#{e.product_name || ""} #{e.product_code || ""}"),
            query
          )
        end)
  end

  defp sort_direction(:asc), do: :asc
  defp sort_direction(:desc), do: :desc

  defp sort_entries(entries, sort),
    do: Enum.sort_by(entries, &sort_value(&1, sort.key), sort_direction(sort.direction))

  defp sort_value(entry, key)
       when key in [
              "product_cost",
              "product_price",
              "total_quantity",
              "quantity",
              "prev_quantity"
            ],
       do: value(entry, String.to_atom(key)) || 0

  defp sort_value(entry, key),
    do: value(entry, String.to_atom(key)) |> to_string() |> String.downcase()

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp money(value), do: :erlang.float_to_binary(decimal(value), decimals: 2) |> then(&"$#{&1}")
  defp decimal(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal(value) when is_number(value), do: value * 1.0

  defp decimal(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> 0.0
    end
  end

  defp decimal(_), do: 0.0
  defp number_input(nil), do: ""
  defp number_input(value), do: :erlang.float_to_binary(decimal(value), decimals: 2)
  defp datetime(nil), do: "—"
  defp datetime(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%d/%m/%Y %-I:%M %p")
  defp datetime(value), do: to_string(value)
  defp trace_name("sale"), do: "Sale"
  defp trace_name("inventory_adjustment"), do: "Adjustment"
  defp trace_name("purchase"), do: "Purchase"
  defp trace_name("store_transfer_out"), do: "Transfer out"
  defp trace_name("store_transfer_in"), do: "Transfer in"
  defp trace_name(value), do: value

  defp trace_context(trace) do
    metadata = value(trace, :metadata) || %{}

    context =
      [
        if(value(trace, :customer_name), do: "Customer: #{value(trace, :customer_name)}"),
        if(value(metadata, :provider_name), do: "Provider: #{value(metadata, :provider_name)}"),
        if(value(trace, :destination_store_name),
          do: "To: #{value(trace, :destination_store_name)}"
        ),
        if(value(trace, :source_store_name) && value(trace, :event_type) == "store_transfer_in",
          do: "From: #{value(trace, :source_store_name)}"
        ),
        if(value(trace, :reference_type),
          do:
            "#{String.replace(value(trace, :reference_type), "_", " ")} ##{value(trace, :reference_id)}"
        )
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" · ")

    if context == "", do: "—", else: context
  end

  defp metric(title, value, detail, tone \\ ""),
    do: %{title: title, value: value, detail: detail, tone: tone}

  defp metrics(nil), do: []

  defp metrics(summary) do
    [
      metric(
        "Negative stock",
        "#{value(summary, :negative_stock_sku_count) || 0} SKUs",
        "#{value(summary, :negative_stock_units) || 0} units · #{money(value(summary, :negative_stock_value))}",
        "inventory-summary-negative inventory-summary-compact"
      ),
      metric(
        "Uncosted inventory",
        "#{value(summary, :uncosted_inventory_sku_count) || 0} SKUs",
        "#{value(summary, :uncosted_inventory_units) || 0} units · Cost",
        "inventory-summary-warning inventory-summary-compact"
      ),
      metric(
        "Stockout",
        percent(value(summary, :zero_stock_rate)),
        "#{value(summary, :zero_stock_sku_count) || 0} / #{value(summary, :inventoried_sku_count) || 0} SKUs",
        "inventory-summary-warning"
      ),
      metric(
        "Net sales",
        money(value(summary, :net_sales)),
        "#{value(summary, :sale_transaction_count) || 0} sales"
      ),
      metric(
        "Sales mix",
        money(value(summary, :net_sales)),
        compact(
          value(summary, :sales_mix),
          fn item ->
            "#{value(item, :sale_type) || "Sales"}/#{value(item, :login) || "—"}: #{money(value(item, :net_sales))}"
          end,
          "No activity"
        )
      ),
      metric(
        "Average order",
        money(value(summary, :average_order_value)),
        "#{Float.round(decimal(value(summary, :units_per_order)), 1)} units"
      ),
      metric(
        "Best products",
        compact(value(summary, :best_products), fn item ->
          "#{value(item, :product_name)}: #{money(value(item, :net_revenue))}"
        end),
        compact(
          value(summary, :slowest_products),
          fn item ->
            "#{value(item, :product_name)}: #{Float.round(decimal(value(item, :net_units)), 0)} units"
          end,
          "No activity"
        )
      ),
      metric(
        "Discount rate",
        percent(value(summary, :discount_rate)),
        "#{money(value(summary, :net_discount))} discount"
      ),
      metric(
        "Payment mix",
        compact(value(summary, :payment_method_mix), fn item ->
          "#{value(item, :type)}: #{money(value(item, :amount))}"
        end),
        "Recorded payments"
      ),
      metric(
        "Retention",
        "#{value(summary, :returning_customer_count) || 0} customers",
        "#{value(summary, :purchasing_customer_count) || 0} customers · #{money(value(summary, :average_customer_value))}"
      ),
      metric(
        "Order flow",
        "#{value(summary, :open_purchase_order_count) || 0} purchase orders",
        "#{value(summary, :closed_purchase_order_count) || 0} closed · #{percent(value(summary, :receiving_completion_rate))}"
      )
    ]
  end

  defp compact(items, formatter, empty \\ "No activity")

  defp compact(items, formatter, empty) when is_list(items),
    do: if(items == [], do: empty, else: items |> Enum.map(formatter) |> Enum.join(" · "))

  defp compact(_, _, empty), do: empty
  defp percent(value), do: :erlang.float_to_binary(decimal(value) * 100, decimals: 1) <> "%"

  @impl true
  def render(assigns) do
    ~H"""
    <.pos_layout
      id="inventory-live"
      class="pos-shell invoice-view"
      active_page={:inventory}
      scope={@scope}
      stores={@stores}
      store_id={@store_id}
      phx-hook="InventoryScreen"
    >
      <section class="catalog-panel" data-view="inventory" aria-labelledby="inventory-title">
        <section id="inventory-screen" class="operations-screen" aria-labelledby="inventory-title">
          <div class="operations-fixed">
            <header class="topbar operations-topbar">
              <div class="brand-lockup">
                <span class="brand-mark" aria-hidden="true">E</span>
                <div>
                  <p class="eyebrow">Operations</p>
                  <h2 id="inventory-title" tabindex="-1">Inventory — {active_store(assigns)}</h2>
                </div>
              </div>
              <form class="operations-filters" phx-change="search" phx-submit="search">
                <div class="search-field">
                  <svg class="search-icon" aria-hidden="true"><use href="#ui-icon-search" /></svg>
                  <input
                    id="inventory-search"
                    name="value"
                    class="input"
                    type="search"
                    value={@search}
                    phx-debounce="0"
                    placeholder="Search product"
                    autocomplete="off"
                  />
                </div>
                <label class="inventory-checkbox-label inventory-archived-filter" for="inventory-show-archived">
                  <input
                    id="inventory-show-archived"
                    type="checkbox"
                    checked={@show_archived?}
                    phx-click="toggle_archived"
                  />Archived
                </label>
                <button
                  :if={Scope.allowed?(@scope, "product.add")}
                  id="create-product"
                  class="btn"
                  type="button"
                  data-variant="default"
                  aria-haspopup="dialog"
                  phx-click="open_product_dialog"
                >
                  Create product
                </button>
              </form>
            </header>
            <p id="inventory-status" class="operations-status" role="status">{@status}</p>
          </div>
          <section class="inventory-summary-section" aria-label="Inventory and operations KPIs">
            <section
              id="inventory-summary"
              class={["inventory-summary", if(!@kpis_expanded, do: "is-collapsed")]}
              aria-live="polite"
            >
              <article class="card inventory-summary-card inventory-summary-valuation">
                <div class="card-header">
                  <p class="card-title">Inventory valuation</p>
                </div>
                <div class="card-content inventory-valuation-content">
                  <div class="inventory-valuation-company">
                    <p class="inventory-kpi-value numeric">
                      {money(value(@summary || %{}, :company_inventory_valuation))}
                    </p>
                    <p class="inventory-valuation-caption numeric">Company total</p>
                  </div>
                  <div class="inventory-valuation-breakdown">
                    <div
                      :for={store <- value(@summary || %{}, :inventory_valuation_by_store) || []}
                      class="inventory-valuation-store"
                    >
                      <p class="inventory-valuation-store-amount numeric">
                        {money(value(store, :inventory_valuation))}
                      </p>
                      <p class="inventory-valuation-store-name">
                        {value(store, :store_name) || "Store"}
                      </p>
                    </div>
                  </div>
                </div>
              </article>
              <article
                :for={card <- metrics(@summary)}
                class={["card inventory-summary-card", card.tone]}
              >
                <button
                  :if={card.title in ["Negative stock", "Uncosted inventory"]}
                  class="btn inventory-kpi"
                  type="button"
                  data-variant={
                    if @filter ==
                         if(card.title == "Negative stock", do: "negative", else: "uncosted"),
                       do: "secondary",
                       else: "ghost"
                  }
                  aria-pressed={
                    to_string(
                      @filter == if(card.title == "Negative stock", do: "negative", else: "uncosted")
                    )
                  }
                  phx-click="toggle_filter"
                  phx-value-filter={
                    if(card.title == "Negative stock", do: "negative", else: "uncosted")
                  }
                >
                  <div class="card-header">
                    <p class="card-title">{card.title}</p>
                  </div>
                  <div class="card-content">
                    <p class="inventory-kpi-value numeric">{card.value}</p>
                    <p class="inventory-kpi-detail">{card.detail}</p>
                  </div>
                </button>
                <div
                  :if={card.title not in ["Negative stock", "Uncosted inventory"]}
                  class="inventory-kpi"
                >
                  <div class="card-header">
                    <p class="card-title">{card.title}</p>
                  </div>
                  <div class="card-content">
                    <p class="inventory-kpi-value numeric">{card.value}</p>
                    <p class="inventory-kpi-detail">{card.detail}</p>
                  </div>
                </div>
              </article>
            </section>
            <button
              id="inventory-kpis-toggle"
              class="btn inventory-kpis-toggle"
              type="button"
              data-variant="ghost"
              phx-click="toggle_kpis"
              aria-expanded={to_string(@kpis_expanded)}
              aria-controls="inventory-summary"
            >
              {if @kpis_expanded, do: "Show fewer KPIs", else: "Show more KPIs"}
              <span aria-hidden="true">⌄</span>
            </button>
          </section>
          <div class="table-container operations-table-container">
            <table class="table operations-table">
              <caption class="table-caption">Inventory by store.</caption>
              <thead>
                <tr class="table-row">
                  <th
                    :for={{label, key} <- headers()}
                    class={[
                      "table-head",
                      if(is_nil(key), do: "inventory-status-head"),
                      if(key == "total_quantity", do: "inventory-total-quantity-cell"),
                      if(key == "prev_quantity", do: "inventory-previous-quantity-cell")
                    ]}
                    scope="col"
                    aria-sort={if key, do: sort_aria(@sort, key), else: nil}
                  >
                    <button
                      :if={key}
                      class="btn operations-sort"
                      type="button"
                      data-variant="ghost"
                      phx-click="sort"
                      phx-value-key={key}
                    >
                      {label}
                    </button>
                    <span :if={is_nil(key)} class="sr-only">{label}</span>
                  </th>
                </tr>
              </thead>
              <tbody id="inventory-table-body">
                <%= for entry <- visible_entries(assigns) do %>
                  <tr class="table-row" data-inventory-product-id={entry.product_id}>
                    <td class="table-cell" data-label="Product">
                      <button
                        class="btn"
                        type="button"
                        data-variant="link"
                        phx-click="open_product_editor"
                        phx-value-product_id={entry.product_id}
                      >
                        {entry.product_name || "Product ##{entry.product_id}"}
                      </button>
                    </td>
                    <td class="table-cell inventory-product-status-cell" data-label="Status">
                      <details class="inventory-product-status-menu">
                        <summary
                          class={["inventory-product-status", product_status_tone(entry)]}
                          title={product_status_label(entry)}
                          aria-label={"Product status: #{product_status_label(entry)}"}
                        >
                          <.product_status_icon entry={entry} />
                        </summary>
                        <div class="inventory-product-status-options" role="menu">
                          <button
                            class={[
                              "inventory-product-status-option",
                              if(product_active?(entry), do: "is-checked")
                            ]}
                            type="button"
                            role="menuitem"
                            aria-checked={to_string(product_active?(entry))}
                            phx-click="set_product_status"
                            phx-value-product_id={entry.product_id}
                            phx-value-status="active"
                          >
                            <span class="inventory-product-status-mini is-active">
                              <.product_status_icon entry={%{active: 1, archived: "0"}} />
                            </span>
                            Active
                          </button>
                          <button
                            class={[
                              "inventory-product-status-option",
                              if(product_archived?(entry), do: "is-checked")
                            ]}
                            type="button"
                            role="menuitem"
                            aria-checked={to_string(product_archived?(entry))}
                            phx-click="set_product_status"
                            phx-value-product_id={entry.product_id}
                            phx-value-status="archived"
                          >
                            <span class="inventory-product-status-mini is-archived">
                              <.product_status_icon entry={%{active: 1, archived: "1"}} />
                            </span>
                            Archive it
                          </button>
                        </div>
                      </details>
                    </td>
                    <td class="table-cell" data-label="SKU">
                      <button
                        class="btn inventory-sku-trace"
                        type="button"
                        data-variant="link"
                        phx-click="toggle_traces"
                        phx-value-product_id={entry.product_id}
                        aria-expanded={to_string(@expanded == {:traces, entry.product_id})}
                      >
                        {entry.product_code || "—"}
                      </button>
                    </td>
                    <td class="table-cell numeric" data-label="Cost">{money(entry.product_cost)}</td>
                    <td class="table-cell numeric" data-label="Price">
                      {if is_nil(entry.product_price), do: "—", else: money(entry.product_price)}
                    </td>
                    <td class="table-cell numeric inventory-total-quantity-cell" data-label="Total quantity">
                      <button
                        class="btn inventory-total-quantity"
                        type="button"
                        data-variant="link"
                        phx-click="toggle_quantities"
                        phx-value-product_id={entry.product_id}
                        aria-expanded={to_string(@expanded == {:quantities, entry.product_id})}
                      >
                        <span class="inventory-total-quantity-indicator" aria-hidden="true">{if @expanded == {:quantities, entry.product_id}, do: "▾", else: "▸"}</span>{entry.total_quantity ||
                          entry.quantity || 0}
                      </button>
                    </td>
                    <td class="table-cell" data-label="Current quantity">
                      <%= if @editing_product_id == entry.product_id do %>
                        <form class="inventory-inline-editor" phx-submit="save_quantity">
                          <input type="hidden" name="product_id" value={entry.product_id} /><input
                            id={"inventory-quantity-#{entry.product_id}"}
                            class="input"
                            name="quantity"
                            type="number"
                            value={entry.quantity || 0}
                          /><button class="btn" type="submit" data-variant="default" data-size="sm">
                            Update
                          </button><button
                            class="btn"
                            type="button"
                            data-variant="ghost"
                            data-size="sm"
                            phx-click="cancel_edit"
                          >Cancel</button>
                        </form>
                      <% else %>
                        <div class="inventory-inline-editor">
                          <span>{entry.quantity || 0}</span><button
                            class="btn"
                            type="button"
                            data-variant="outline"
                            data-size="sm"
                            phx-click="edit_quantity"
                            phx-value-product_id={entry.product_id}
                          >Update</button>
                        </div>
                      <% end %>
                    </td>
                    <td class="table-cell numeric inventory-previous-quantity-cell" data-label="Previous quantity">
                      {entry.prev_quantity || "—"}
                    </td>
                    <td class="table-cell" data-label="Last updated">
                      {datetime(entry.last_update)}
                    </td>
                    <td class="table-cell" data-label="Updated by">{entry.user_updated || "—"}</td>
                  </tr>
                  <tr
                    :for={store <- @store_quantities}
                    :if={@expanded == {:quantities, entry.product_id}}
                    class="table-row inventory-store-row"
                  >
                    <td class="table-cell" colspan="4"></td>
                    <td class="table-cell inventory-store-name" data-label="Store">
                      {store.store_name}
                    </td>
                    <td class="table-cell inventory-total-quantity-cell" data-label="Total quantity"></td>
                    <td class="table-cell" data-label="Current quantity">
                      <form class="inventory-inline-editor" phx-submit="save_store_quantity">
                        <input type="hidden" name="product_id" value={entry.product_id} /><input
                          type="hidden"
                          name="store_id"
                          value={store.store_id}
                        /><input
                          id={"inventory-store-quantity-#{entry.product_id}-#{store.store_id}"}
                          class="input"
                          name="quantity"
                          type="number"
                          value={store.quantity || 0}
                        /><button class="btn" type="submit" data-variant="default" data-size="sm">
                          Update
                        </button>
                      </form>
                    </td>
                    <td class="table-cell inventory-previous-quantity-cell" data-label="Previous quantity">
                      {store.prev_quantity || "—"}
                    </td>
                    <td class="table-cell" data-label="Last updated">
                      {datetime(store.last_update)}
                    </td>
                    <td class="table-cell" data-label="Updated by">{store.user_updated || "—"}</td>
                  </tr>
                  <tr
                    :if={@expanded == {:traces, entry.product_id}}
                    class="table-row inventory-traces-row"
                  >
                    <td class="table-cell" colspan="10">
                      <%= if @traces == [] do %>
                        <p class="field-description">No trace history yet.</p>
                      <% else %>
                        <div class="inventory-trace-wrap">
                          <table class="table inventory-trace-table">
                            <thead>
                              <tr class="table-row">
                                <th class="table-head">Date</th>
                                <th class="table-head">Action</th>
                                <th class="table-head">Store</th>
                                <th class="table-head">Change</th>
                                <th class="table-head">Previous → Current</th>
                                <th class="table-head">Updated by</th>
                                <th class="table-head">Context</th>
                              </tr>
                            </thead>
                            <tbody>
                              <tr :for={trace <- @traces} class="table-row">
                                <td class="table-cell">{datetime(value(trace, :inserted_at))}</td>
                                <td class="table-cell">{trace_name(value(trace, :event_type))}</td>
                                <td class="table-cell">{value(trace, :store_name) || "—"}</td>
                                <td class="table-cell numeric">
                                  {if decimal(value(trace, :quantity_change)) > 0, do: "+", else: ""}{value(
                                    trace,
                                    :quantity_change
                                  )}
                                </td>
                                <td class="table-cell numeric">
                                  {value(trace, :quantity_before)} → {value(trace, :quantity_after)}
                                </td>
                                <td class="table-cell">{value(trace, :operator_username) || "—"}</td>
                                <td class="table-cell">{trace_context(trace)}</td>
                              </tr>
                            </tbody>
                          </table>
                        </div>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>
      </section>
      <dialog
        :if={@product_dialog}
        id="product-dialog"
        class="dialog"
        data-size="lg"
        role="dialog"
        aria-modal="true"
        aria-labelledby="product-dialog-title"
      >
        <div class="dialog-content">
          <div class="dialog-header">
            <h2 id="product-dialog-title" class="dialog-title">
              {if @editing_product, do: "Edit product", else: "Create product"}
            </h2>
            <p id="product-dialog-description" class="dialog-description">
              Catalog details and pricing-list values are saved as separate records.
            </p>
          </div>
          <form
            id="product-form"
            class="form dialog-body"
            phx-submit={if @editing_product, do: "update_product", else: "create_product"}
          >
            <div id="product-form-fields" phx-update="ignore">
              <div class="form-field">
                <label class="label" for="product-name">
                  Name <span aria-hidden="true" class="text-destructive">*</span>
                </label>
                <input
                  id="product-name"
                  name="name"
                  class="input"
                  value={@editing_product && @editing_product.name}
                  required
                  autofocus
                />
              </div>
              <div class="product-form-row">
                <div class="form-field">
                  <label class="label" for="product-cost">Cost</label>
                  <input
                    id="product-cost"
                    name="cost"
                    class="input"
                    type="number"
                    min="0"
                    step="0.01"
                    value={number_input(if @editing_product, do: @editing_product.cost || 0, else: 0)}
                  />
                </div>
                <fieldset class="form-fieldset product-prices-fieldset">
                  <legend>Price lists</legend>
                  <div id="product-pricing-fields" class="form-group" aria-live="polite">
                    <div
                      :for={list <- @pricing_lists}
                      class="product-price-row"
                      data-pricing-id={list.id}
                    >
                      <label class="label" for={"product-price-#{list.id}"}>
                        {list.label || "Pricing list ##{list.id}"}
                      </label>
                      <input
                        id={"product-price-#{list.id}"}
                        name={"prices[#{list.id}]"}
                        class="input"
                        type="number"
                        min="0"
                        step="0.01"
                        placeholder="Price"
                        value={number_input(price_for(@editing_product, list.id))}
                        required={list.id == 1}
                        aria-label={"Price for #{list.label}"}
                      />
                    </div>
                  </div>
                </fieldset>
              </div>
              <div class="form-field">
                <label class="label" for="product-code">SKU</label>
                <input
                  id="product-code"
                  name="code"
                  class="input"
                  value={@editing_product && @editing_product.code}
                />
              </div>
              <div class="product-status-fieldset" role="group" aria-labelledby="product-status-label">
                <span id="product-status-label" class="label product-status-label">Status</span>
                <input type="hidden" name="active" value="0" />
                <input type="hidden" name="archived" value="0" />
                <label class="inventory-checkbox-label product-status-option" for="product-active">
                  <input
                    id="product-active"
                    name="active"
                    type="checkbox"
                    value="1"
                    checked={product_active?(@editing_product)}
                  />
                  <svg
                    class="product-status-option-icon"
                    viewBox="0 0 24 24"
                    width="14"
                    height="14"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <circle cx="12" cy="12" r="9" />
                    <path d="m8 12 2.6 2.6L16.5 9" />
                  </svg>
                  <span>Active</span>
                </label>
                <label class="inventory-checkbox-label product-status-option" for="product-archived">
                  <input
                    id="product-archived"
                    name="archived"
                    type="checkbox"
                    value="1"
                    checked={product_archived?(@editing_product)}
                  />
                  <svg
                    class="product-status-option-icon"
                    viewBox="0 0 24 24"
                    width="14"
                    height="14"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M4 7h16" />
                    <path d="M6 7v12h12V7" />
                    <path d="M9 11h6" />
                    <path d="M8 4h8l2 3H6z" />
                  </svg>
                  <span>Archived</span>
                </label>
              </div>
              <div
                id="product-image-dropzone"
                class="product-image-dropzone"
                tabindex="0"
                role="button"
                aria-describedby="product-image-help"
              >
                <img
                  id="product-image-preview"
                  class="product-image-preview"
                  src={image_source(@editing_product && @editing_product.image_raw)}
                  alt="Product preview"
                  hidden={is_nil(@editing_product && @editing_product.image_raw)}
                /><label class="label" for="product-image">Image upload</label>
                <p id="product-image-help" class="field-description">
                  Drop an image here or choose a file (max 10 MB). It will be resized and stored as Base64.
                </p>
                <input id="product-image" class="input" type="file" accept="image/*" /><input
                  id="product-image-raw"
                  name="image_raw"
                  type="hidden"
                  value={@editing_product && @editing_product.image_raw}
                />
              </div>
            </div>
            <p id="product-form-status" class="field-description" role="status">
              {@product_form_status}
            </p>
            <div class="dialog-footer">
              <button
                class="btn"
                type="button"
                data-variant="outline"
                phx-click="close_product_dialog"
              >
                Cancel
              </button><button class="btn" type="submit" data-variant="default">Save</button>
            </div>
          </form>
        </div>
      </dialog>
    </.pos_layout>
    """
  end

  defp headers,
    do: [
      {"Product", "product_name"},
      {"Status", nil},
      {"SKU", "product_code"},
      {"Cost", "product_cost"},
      {"Price", "product_price"},
      {"Total quantity", "total_quantity"},
      {"Current quantity", "quantity"},
      {"Previous quantity", "prev_quantity"},
      {"Last updated", "last_update"},
      {"Updated by", "user_updated"}
    ]

  defp price_for(nil, _pricing_id), do: nil

  defp price_for(product, pricing_id),
    do:
      Enum.find_value(product.prices, fn price ->
        if price.pricing_id == pricing_id, do: price.price
      end)

  defp product_active?(nil), do: true
  defp product_active?(product), do: (value(product, :active) || value(product, :product_active)) == 1

  defp product_archived?(nil), do: false
  defp product_archived?(product),
    do: (value(product, :archived) || value(product, :product_archived)) == "1"

  defp product_status_label(entry) do
    cond do
      product_archived?(entry) -> "Archived"
      product_active?(entry) -> "Active"
      true -> "Not active"
    end
  end

  defp product_status_tone(entry) do
    cond do
      product_archived?(entry) -> "is-archived"
      product_active?(entry) -> "is-active"
      true -> "is-inactive"
    end
  end

  attr :entry, :map, required: true

  defp product_status_icon(assigns) do
    ~H"""
    <svg :if={product_archived?(@entry)} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 7h16" />
      <path d="M6 7v12h12V7" />
      <path d="M9 11h6" />
      <path d="M8 4h8l2 3H6z" />
    </svg>
    <svg :if={!product_archived?(@entry) && product_active?(@entry)} viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="m8 12 2.6 2.6L16.5 9" />
    </svg>
    <svg :if={!product_archived?(@entry) && !product_active?(@entry)} viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M5.7 5.7 18.3 18.3" />
    </svg>
    """
  end

  defp image_source(nil), do: nil
  defp image_source("data:image/" <> _ = source), do: source
  defp image_source(source), do: "data:image/jpeg;base64,#{source}"

  defp sort_aria(sort, key) when sort.key == key,
    do: if(sort.direction == :asc, do: "ascending", else: "descending")

  defp sort_aria(_, _), do: "none"

  defp active_store(assigns),
    do:
      Enum.find_value(assigns.stores, "", fn store ->
        if store.id == assigns.store_id, do: store.name
      end)

  defp selected_store(stores, selected_id) do
    case Integer.parse(to_string(selected_id || "")) do
      {id, ""} -> Enum.find(stores, List.first(stores), &(&1.id == id))
      _ -> List.first(stores)
    end
  end
end
