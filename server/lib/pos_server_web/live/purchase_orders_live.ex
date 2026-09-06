defmodule PosServerWeb.PurchaseOrdersLive do
  @moduledoc false
  use PosServerWeb, :live_view

  alias PosServer.{Authentication, InventoryEvents, TenantContext}
  alias PosServer.Accounts.Scope
  alias PosServer.Retaily.{InventoryContext, Orders}

  @sort_keys ~w(id from_origin_id to_store_id status last_updated user_requester)

  @impl true
  def mount(_params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, scope} <- Authentication.authenticate(token),
         true <- Scope.allowed?(scope, "inventory.view"),
         _ <- TenantContext.put_tenant(scope.tenant),
         {:ok, stores} <- InventoryContext.stores(scope),
         %{id: store_id} <- List.first(stores) do
      socket = socket
      |> assign(:page_title, "Tigoo Purchase orders")
      |> assign(:scope, scope) |> assign(:stores, stores) |> assign(:store_id, store_id)
      |> assign(:orders, []) |> assign(:sources, []) |> assign(:status_counts, %{})
      |> assign(:status_filter, "") |> assign(:sort, %{key: "last_updated", direction: :desc})
      |> assign(:view, :list) |> assign(:selected_order, nil) |> assign(:counting?, false)
      |> assign(:mode, :purchase) |> assign(:lines, [%{id: "line-1", product_id: nil, query: "", quantity: "", current_quantity: "—"}])
      |> assign(:source_id, "") |> assign(:destination_id, to_string(store_id))
      |> assign(:status, "Loading purchase orders…") |> load_orders()

      if connected?(socket), do: InventoryEvents.subscribe(scope.tenant, store_id)
      {:ok, socket}
    else
      _ -> {:ok, socket |> put_flash(:error, "Inventory access is required.") |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("change_store", %{"store_id" => id}, socket) do
    with {store_id, ""} <- Integer.parse(id), true <- Enum.any?(socket.assigns.stores, &(&1.id == store_id)),
         {:ok, _} <- InventoryContext.authorize_store(socket.assigns.scope, store_id) do
      InventoryEvents.unsubscribe(socket.assigns.scope.tenant, socket.assigns.store_id)
      if connected?(socket), do: InventoryEvents.subscribe(socket.assigns.scope.tenant, store_id)
      {:noreply, socket |> assign(:store_id, store_id) |> reset_view() |> load_orders()}
    else
      _ -> {:noreply, put_flash(socket, :error, "The selected store is unavailable.")}
    end
  end

  def handle_event("sort", %{"key" => key}, socket) when key in @sort_keys do
    sort = if socket.assigns.sort.key == key, do: %{key: key, direction: flip(socket.assigns.sort.direction)}, else: %{key: key, direction: :asc}
    {:noreply, socket |> assign(:sort, sort) |> update(:orders, &sort_orders(&1, sort))}
  end
  def handle_event("toggle_status", %{"status" => status}, socket) do
    filter = if socket.assigns.status_filter == status, do: "", else: status
    {:noreply, socket |> assign(:status_filter, filter) |> load_orders()}
  end
  def handle_event("reload_orders", _, socket), do: {:noreply, load_orders(socket)}
  def handle_event("show_order", %{"id" => id}, socket), do: {:noreply, show_order(socket, integer(id))}
  def handle_event("back_to_orders", _, socket), do: {:noreply, socket |> reset_view() |> load_orders()}
  def handle_event("navigate_order", %{"direction" => direction}, socket) do
    current = socket.assigns.selected_order && socket.assigns.selected_order.id
    index = Enum.find_index(socket.assigns.orders, &(&1.id == current)) || 0
    offset = if direction == "previous", do: -1, else: 1
    {:noreply, show_order(socket, socket.assigns.orders |> Enum.at(index + offset, %{}) |> value(:id))}
  end
  def handle_event("start_counting", _, socket), do: {:noreply, socket |> assign(:counting?, true) |> push_event("purchase-orders:focus-observed", %{index: 0})}
  def handle_event("observed_key", %{"index" => index, "key" => key}, socket) when key in ["Enter", "ArrowDown", "ArrowUp"] do
    delta = if key == "ArrowUp", do: -1, else: 1
    {:noreply, push_event(socket, "purchase-orders:focus-observed", %{index: max(0, integer(index) + delta)})}
  end

  def handle_event("receive_order", %{"observed" => observed}, socket) do
    lines = Enum.map(socket.assigns.selected_order.lines, fn line -> %{id: line.id, quantity_observed: integer(Map.get(observed, to_string(line.id), line.quantity))} end)
    case Orders.receive_order(socket.assigns.scope, socket.assigns.selected_order.id, %{lines: lines}) do
      {:ok, order} -> {:noreply, socket |> replace_order(order) |> assign(:selected_order, order) |> assign(:counting?, false) |> put_flash(:info, "Order processed.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Order could not be processed: #{reason_message(reason)}")}
    end
  end

  def handle_event("open_create", _, socket), do: {:noreply, open_form(socket, :purchase)}
  def handle_event("open_move", _, socket), do: {:noreply, open_form(socket, :move)}
  def handle_event("add_line", _, socket), do: {:noreply, update(socket, :lines, &(&1 ++ [blank_line(length(&1) + 1)]))}
  def handle_event("remove_line", %{"id" => id}, socket), do: {:noreply, update(socket, :lines, &Enum.reject(&1, fn line -> line.id == id end))}
  def handle_event("line_product", %{"id" => id, "product_id" => product_id}, socket) do
    {:noreply, update_line(socket, id, fn line -> Map.merge(line, %{product_id: integer(product_id), query: product_name(socket.assigns.products, product_id)}) end) |> refresh_line_quantity(id)}
  end
  def handle_event("line_quantity", %{"id" => id, "value" => quantity}, socket), do: {:noreply, update_line(socket, id, &Map.put(&1, :quantity, quantity))}
  def handle_event("change_source", %{"source_id" => id}, socket), do: {:noreply, socket |> assign(:source_id, id) |> refresh_all_line_quantities()}
  def handle_event("change_destination", %{"destination_id" => id}, socket), do: {:noreply, socket |> assign(:destination_id, id) |> refresh_all_line_quantities()}

  def handle_event("submit_order", _params, socket) do
    lines = valid_lines(socket.assigns.lines)
    cond do
      lines == [] -> {:noreply, put_flash(socket, :error, "Add a product with a requested quantity.")}
      socket.assigns.mode == :move and socket.assigns.source_id == socket.assigns.destination_id -> {:noreply, put_flash(socket, :error, "Origin Store and Destination Store must be different.")}
      socket.assigns.mode == :purchase -> create_purchase(socket, lines)
      true -> move_products(socket, lines)
    end
  end

  @impl true
  def handle_info({:inventory_changed, _}, socket) do
    socket = if socket.assigns.view == :detail, do: refresh_selected_order(socket), else: socket
    {:noreply, socket}
  end

  defp create_purchase(socket, lines) do
    attrs = %{order_type: "purchase", from_origin_id: integer(socket.assigns.source_id), to_store_id: integer(socket.assigns.destination_id), lines: lines}
    case Orders.create_order(socket.assigns.scope, attrs) do
      {:ok, order} -> {:noreply, socket |> update(:orders, &[order | &1]) |> assign(:selected_order, order) |> assign(:view, :detail) |> put_flash(:info, "Purchase order created.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Order could not be created: #{reason_message(reason)}")}
    end
  end
  defp move_products(socket, lines) do
    attrs = %{from_origin_id: integer(socket.assigns.source_id), to_store_id: integer(socket.assigns.destination_id), lines: lines}
    case Orders.move_inventory(socket.assigns.scope, attrs) do
      {:ok, _} -> {:noreply, socket |> reset_view() |> load_orders() |> put_flash(:info, "Products moved. Inventory was updated for both stores.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Products could not be moved: #{reason_message(reason)}")}
    end
  end

  defp load_orders(socket) do
    case {Orders.list_orders(socket.assigns.scope, socket.assigns.store_id, blank_to_nil(socket.assigns.status_filter)), Orders.list_purchase_sources(socket.assigns.scope, socket.assigns.store_id), InventoryContext.list(socket.assigns.scope, socket.assigns.store_id, nil)} do
      {{:ok, %{entries: orders, status_counts: counts}}, {:ok, sources}, {:ok, inventory}} -> socket |> assign(:orders, sort_orders(orders, socket.assigns.sort)) |> assign(:status_counts, counts) |> assign(:sources, sources) |> assign(:products, Enum.map(inventory, &%{id: &1.product_id, name: &1.product_name, code: &1.product_code})) |> assign(:status, order_status(orders))
      {{:ok, %{entries: orders, status_counts: counts}}, {:ok, sources}, _} -> socket |> assign(:orders, sort_orders(orders, socket.assigns.sort)) |> assign(:status_counts, counts) |> assign(:sources, sources) |> assign(:products, []) |> assign(:status, order_status(orders))
      _ -> assign(socket, :status, "Purchase orders could not be loaded.")
    end
  end
  defp refresh_selected_order(socket) do
    case Orders.list_orders(socket.assigns.scope, socket.assigns.store_id, nil) do
      {:ok, %{entries: orders}} ->
        id = socket.assigns.selected_order.id
        socket |> assign(:orders, sort_orders(orders, socket.assigns.sort)) |> assign(:selected_order, Enum.find(orders, &(&1.id == id), socket.assigns.selected_order))
      _ -> socket
    end
  end
  defp show_order(socket, nil), do: socket
  defp show_order(socket, id), do: socket |> assign(:selected_order, Enum.find(socket.assigns.orders, &(&1.id == id))) |> assign(:view, :detail) |> assign(:counting?, false)
  defp reset_view(socket), do: socket |> assign(:view, :list) |> assign(:selected_order, nil) |> assign(:counting?, false)
  defp open_form(socket, mode), do: socket |> assign(:view, :form) |> assign(:mode, mode) |> assign(:source_id, if(mode == :move, do: to_string(socket.assigns.store_id), else: "")) |> assign(:destination_id, to_string(socket.assigns.store_id)) |> assign(:lines, [blank_line(1)])
  defp replace_order(socket, order), do: update(socket, :orders, fn orders -> Enum.map(orders, fn current -> if current.id == order.id, do: order, else: current end) |> sort_orders(socket.assigns.sort) end)
  defp blank_line(number), do: %{id: "line-#{number}-#{System.unique_integer([:positive])}", product_id: nil, query: "", quantity: "", current_quantity: "—"}
  defp update_line(socket, id, fun), do: update(socket, :lines, &Enum.map(&1, fn line -> if line.id == id, do: fun.(line), else: line end))
  defp refresh_all_line_quantities(socket), do: Enum.reduce(socket.assigns.lines, socket, fn line, acc -> refresh_line_quantity(acc, line.id) end)
  defp refresh_line_quantity(socket, id) do
    line = Enum.find(socket.assigns.lines, &(&1.id == id))
    store_id = integer(if socket.assigns.mode == :move, do: socket.assigns.source_id, else: socket.assigns.destination_id)
    quantity = if line && line.product_id && store_id > 0 do
      case InventoryContext.list(socket.assigns.scope, store_id, nil) do
        {:ok, entries} -> entries |> Enum.find(&(&1.product_id == line.product_id), %{}) |> value(:quantity) || 0
        _ -> "—"
      end
    else
      "—"
    end
    update_line(socket, id, &Map.put(&1, :current_quantity, quantity))
  end
  defp valid_lines(lines), do: lines |> Enum.map(fn line -> %{product_id: line.product_id, quantity: integer(line.quantity)} end) |> Enum.filter(&(&1.product_id && &1.quantity > 0))
  defp sort_orders(orders, sort), do: Enum.sort_by(orders, &sort_value(&1, sort.key), if(sort.direction == :asc, do: :asc, else: :desc))
  defp sort_value(order, key) when key in ["id"], do: value(order, String.to_atom(key)) || 0
  defp sort_value(order, key), do: value(order, String.to_atom(key)) |> to_string() |> String.downcase()
  defp flip(:asc), do: :desc
  defp flip(:desc), do: :asc
  defp integer(value) when is_integer(value), do: value
  defp integer(value) do
    case Integer.parse(to_string(value || "")) do
      {number, _} -> number
      :error -> 0
    end
  end
  defp value(nil, _), do: nil
  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
  defp order_status([]), do: "No purchase orders found."
  defp order_status(orders), do: "#{length(orders)} purchase orders"
  defp product_name(products, id), do: products |> Enum.find(fn product -> to_string(product.id) == to_string(id) end, %{}) |> value(:name) || ""
  defp reason_message(%Ecto.Changeset{}), do: "Check the required fields."
  defp reason_message(reason), do: to_string(reason)
  defp money(value), do: "$" <> :erlang.float_to_binary(decimal(value), decimals: 2)
  defp decimal(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal(value) when is_number(value), do: value * 1.0
  defp decimal(_), do: 0.0
  defp datetime(nil), do: "—"
  defp datetime(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%d/%m/%Y %-I:%M %p")
  defp datetime(value), do: to_string(value)
  defp closed?(order), do: value(order, :status) in ["received", "closed"]
  defp requested_cost(line), do: decimal(value(line, :product_cost)) * (value(line, :quantity) || 0)
  defp line_cost(line, order), do: decimal(value(line, :product_cost)) * if(closed?(order), do: value(line, :quantity_observed) || value(line, :quantity) || 0, else: value(line, :quantity) || 0)
  defp difference(line, order), do: if(closed?(order), do: line_cost(line, order) - requested_cost(line), else: 0.0)
  defp order_cost(order), do: Enum.reduce(value(order, :lines) || [], 0.0, &(line_cost(&1, order) + &2))
  defp order_difference(order), do: Enum.reduce(value(order, :lines) || [], 0.0, &(difference(&1, order) + &2))
  defp discrepancy?(order), do: closed?(order) && Enum.any?(value(order, :lines) || [], fn line -> (value(line, :quantity_observed) || value(line, :quantity)) != value(line, :quantity) end)
  defp sort_aria(sort, key) when sort.key == key, do: if(sort.direction == :asc, do: "ascending", else: "descending")
  defp sort_aria(_, _), do: "none"
  defp source_options(:move, stores, _sources), do: stores
  defp source_options(_, _stores, sources), do: sources

  @impl true
  def render(assigns) do
    ~H"""
    <main id="purchase-orders-live" class="pos-shell invoice-view">
      <nav class="sidebar-rail" aria-label="Primary navigation">
        <a class="sidebar-link" href={~p"/pos"} aria-label="POS">▣</a><a class="sidebar-link" href={~p"/pos/invoices"} aria-label="Invoice report">▤</a><a class="sidebar-link" href={~p"/pos/inventory"} aria-label="Inventory">▱</a><a class="sidebar-link" href={~p"/pos/orders"} aria-current="page" aria-label="Purchase orders">▤</a>
      </nav>
      <section class="catalog-panel" data-view="orders" aria-labelledby="orders-title">
        <section :if={@view == :list} id="orders-screen" class="operations-screen" aria-labelledby="orders-title">
          <div class="operations-fixed"><header class="topbar operations-topbar"><div class="brand-lockup"><span class="brand-mark" aria-hidden="true">E</span><div><p class="eyebrow">Operations</p><h2 id="orders-title" tabindex="-1">Purchase orders — {active_store(@stores, @store_id)}</h2></div></div><div class="form-actions"><button class="btn" type="button" data-variant="default" phx-click="open_create">Create purchase order</button><button class="btn" type="button" data-variant="default" phx-click="open_move">Move Product</button></div></header><p class="operations-status" role="status">{@status}</p></div>
          <section class="inventory-summary-section" aria-label="Purchase order status KPIs"><section class="inventory-summary" aria-live="polite"><article :for={{status, count} <- @status_counts} class="card inventory-summary-card"><button class="btn inventory-kpi" type="button" data-variant={if @status_filter == status, do: "secondary", else: "ghost"} aria-pressed={to_string(@status_filter == status)} phx-click="toggle_status" phx-value-status={status}><div class="card-header"><p class="card-title">{status}</p></div><div class="card-content"><p class="inventory-kpi-value numeric">{count}</p><p class="inventory-kpi-detail">Purchase orders</p></div></button></article></section></section>
          <div class="table-container operations-table-container"><table class="table operations-table"><caption class="table-caption">Purchase orders for the current store.</caption><thead><tr class="table-row"><%= for {label, key} <- [{"Order ID", "id"}, {"Source", "from_origin_id"}, {"Destination store", "to_store_id"}, {"Order cost", nil}, {"Cost difference", nil}, {"Status", "status"}, {"Last updated", "last_updated"}, {"Created by", "user_requester"}] do %><th class="table-head" scope="col" aria-sort={if key, do: sort_aria(@sort, key), else: "none"}><button :if={key} class="btn operations-sort" type="button" data-variant="ghost" phx-click="sort" phx-value-key={key}>{label}</button><span :if={!key}>{label}</span></th><% end %><th class="table-head"><span class="sr-only">Action</span></th></tr></thead><tbody><tr :for={order <- @orders} class={["table-row purchase-order-row", if(closed?(order), do: "purchase-order-received", else: "purchase-order-open")] }><td class="table-cell" data-label="Purchase order">#{order.id}</td><td class="table-cell" data-label="Source">{order.from_origin_name || "—"}</td><td class="table-cell" data-label="Destination store">{order.to_store_name || "—"}</td><td class="table-cell numeric" data-label="Order cost">{money(order_cost(order))}</td><td class="table-cell numeric" data-label="Cost difference">{money(order_difference(order))}</td><td class="table-cell" data-label="Status">{if closed?(order), do: "Closed", else: "Open"}<span :if={discrepancy?(order)} class="counting-warning" role="img" aria-label="Observed quantities differ from requested quantities" title="Observed quantities differ from requested quantities"> ⚠</span></td><td class="table-cell" data-label="Last updated">{datetime(order.date_closed || order.date_opened)}</td><td class="table-cell" data-label="Created by">{order.user_requester || "—"}</td><td class="table-cell" data-label="Actions"><button class="btn" type="button" data-variant="outline" data-size="sm" phx-click="show_order" phx-value-id={order.id}>View</button></td></tr></tbody></table></div>
        </section>
        <section :if={@view in [:detail, :form]} id="purchase-order-screen" class="operations-screen purchase-order-screen" aria-labelledby="purchase-order-title"><div class="operations-fixed"><header class="topbar operations-topbar"><div class="brand-lockup"><span class="brand-mark" aria-hidden="true">E</span><div><p class="eyebrow">Operations</p><h2 id="purchase-order-title" tabindex="-1">{if @view == :form and @mode == :move, do: "Move products", else: "Purchase order"} — {active_store(@stores, @store_id)}</h2></div></div><button class="btn" type="button" data-variant="outline" data-size="sm" phx-click="back_to_orders">Back to orders</button></header></div>
          <article :if={@view == :detail} class="card purchase-order-detail"><div class="card-header"><div><p class="eyebrow">Order #{@selected_order.id}</p><h3 class="card-title">{if closed?(@selected_order), do: "Closed", else: "Open"}<span :if={discrepancy?(@selected_order)} class="counting-warning"> ⚠</span></h3><p class="field-description">{@selected_order.from_origin_name || "External source"} → {@selected_order.to_store_name || "—"} · Created by {@selected_order.user_requester || "—"} · {datetime(@selected_order.date_opened)}</p></div><div class="purchase-order-actions"><button class="btn" type="button" data-variant="outline" data-size="sm" phx-click="navigate_order" phx-value-direction="previous" disabled={order_position(@orders, @selected_order.id) <= 0}>Previous</button><button class="btn" type="button" data-variant="outline" data-size="sm" phx-click="navigate_order" phx-value-direction="next" disabled={order_position(@orders, @selected_order.id) >= length(@orders) - 1}>Next</button><button :if={!closed?(@selected_order) and !@counting?} class="btn" type="button" data-variant="default" phx-click="start_counting">Start Counting</button><button :if={!closed?(@selected_order) and @counting?} class="btn" type="submit" form="receive-order-form" data-variant="default">Process Order</button></div></div><form id="receive-order-form" class="card-content" phx-submit="receive_order"><div class="table-container purchase-order-lines-scroll"><table class="table purchase-order-lines-table"><caption class="table-caption">Products in this purchase order.</caption><thead><tr class="table-row"><th class="table-head">Product</th><th class="table-head">SKU</th><th class="table-head">Current quantity</th><th class="table-head">Requested</th><th class="table-head">Observed</th><th class="table-head">Item cost</th><th class="table-head">Cost difference</th><th class="table-head">Status</th></tr></thead><tbody><tr :for={{line, index} <- Enum.with_index(@selected_order.lines)} class="table-row"><td class="table-cell">{line.product_name}</td><td class="table-cell">{line.product_code || "—"}</td><td class="table-cell numeric">{line.current_quantity || 0}</td><td class="table-cell numeric">{line.quantity}</td><td class="table-cell observed-cell"><input class="input numeric observed-input" type="number" min="0" name={"observed[#{line.id}]"} value={line.quantity_observed || line.quantity} disabled={!@counting?} phx-keydown="observed_key" phx-value-index={index}/></td><td class="table-cell numeric">{money(line_cost(line, @selected_order))}</td><td class="table-cell numeric">{money(difference(line, @selected_order))}</td><td class="table-cell">{line.status}</td></tr></tbody><tfoot><tr class="purchase-order-total-row"><td colspan="5"></td><td class="numeric purchase-order-total-amount">{money(order_cost(@selected_order))}</td><td class="numeric purchase-order-difference-amount">{money(order_difference(@selected_order))}</td><td></td></tr></tfoot></table></div></form></article>
          <article :if={@view == :form} class="card purchase-order-detail"><div class="card-header"><div><p class="eyebrow">Operations</p><h3 class="card-title">{if @mode == :move, do: "Move products", else: "Create purchase order"}</h3><p class="field-description">{if @mode == :move, do: "Move products from an origin store to a destination store.", else: "Add products and confirm the requested quantities."}</p></div></div><form class="form card-content" phx-submit="submit_order"><div class="order-form-grid"><div class="form-field"><label class="label" for="purchase-order-source">{if @mode == :move, do: "Origin store", else: "Source / provider"}</label><select id="purchase-order-source" class="select" name="source_id" phx-change="change_source" required><option value="" selected={@source_id == ""} disabled>Select a source</option><option :for={source <- source_options(@mode, @stores, @sources)} value={source.id} selected={to_string(source.id) == @source_id}>{source.name}</option></select></div><div class="form-field"><label class="label" for="purchase-order-destination">Destination store</label><select id="purchase-order-destination" class="select" name="destination_id" phx-change="change_destination" required><option :for={store <- @stores} value={store.id} selected={to_string(store.id) == @destination_id}>{store.name}</option></select></div></div><div class="order-lines"><div :for={line <- @lines} class="order-line"><button class="btn" type="button" data-variant="outline" data-size="icon-sm" disabled={is_nil(line.product_id)} aria-label="Edit selected product">✎</button><div class="product-combobox"><select class="select" aria-label="Product" phx-change="line_product" name="product_id" phx-value-id={line.id}><option value="">Search products</option><option :for={product <- @products} value={product.id} selected={product.id == line.product_id}>{product.name}{if product.code, do: " · #{product.code}", else: ""}</option></select><button class="btn" type="button" data-variant="outline" data-size="icon-sm" aria-label="Create product" disabled>+</button></div><input class="input numeric" type="text" value={line.current_quantity} readonly aria-label="Current inventory quantity"/><input class="input" type="number" min="1" value={line.quantity} aria-label="Requested quantity" phx-change="line_quantity" phx-value-id={line.id}/><button class="btn" type="button" data-variant="ghost" data-size="sm" phx-click="remove_line" phx-value-id={line.id}>Remove</button></div></div><button class="btn" type="button" data-variant="outline" data-size="sm" phx-click="add_line">Add product</button><div class="form-actions"><button class="btn" type="submit" data-variant="default">{if @mode == :move, do: "Move products", else: "Create order"}</button></div></form></article>
        </section>
      </section>
    </main>
    """
  end

  defp active_store(stores, id), do: Enum.find_value(stores, "", fn store -> if store.id == id, do: store.name end)
  defp order_position(orders, id), do: Enum.find_index(orders, &(&1.id == id)) || 0
end
