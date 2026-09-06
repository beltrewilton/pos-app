defmodule PosServerWeb.PosLive do
  use PosServerWeb, :live_view

  alias PosServer.{Authentication, TenantContext}
  alias PosServer.Retaily.{InventoryContext, Sales, Sql}

  @impl true
  def mount(_params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, scope} <- Authentication.authenticate(token),
         _tenant <- TenantContext.put_tenant(scope.tenant),
         {:ok, stores} <- InventoryContext.stores(scope) do
      store = List.first(stores)

      {:ok,
       socket
       |> assign(:page_title, "Tigoo POS")
       |> assign(:scope, scope)
       |> assign(:stores, stores)
       |> assign(:store_id, store && store.id)
       |> assign(:products, [])
       |> assign(:cursor, nil)
       |> assign(:has_more, true)
       |> assign(:loading_products, false)
       |> assign(:product_search, "")
       |> assign(:cart, [])
       |> assign(:selected_customer, nil)
       |> assign(:customers, [])
       |> assign(:customer_search, "")
       |> assign(:checkout_stage, nil)
       |> assign(:dialog, nil)
       |> assign(:discount_target, nil)
       |> assign(:discount_type, "amount")
       |> assign(:discount_input, "0")
       |> assign(:order_discount, 0.0)
       |> assign(:order_discount_type, "amount")
       |> assign(:delivery, 0.0)
       |> assign(:credit, false)
       |> assign(:payments, [%{id: "payment-1", type: "CASH", amount: 0.0}])
       |> assign(:sequence, "CF")
       |> assign(:memo, "")
       |> assign(:mobile_cart_open, false)
       |> load_products()
       |> sync()}
    else
      _ -> {:ok, socket |> put_flash(:error, "Sign in is required to use POS.") |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("search_products", %{"value" => value}, socket), do: {:noreply, assign(socket, :product_search, value)}
  def handle_event("clear_product_search", _, socket), do: {:noreply, assign(socket, :product_search, "")}
  def handle_event("load_more_products", _, socket), do: {:noreply, load_products(socket)}

  def handle_event("change_store", %{"store_id" => id}, socket) do
    store_id = String.to_integer(id)
    socket = socket |> assign(:store_id, store_id) |> assign(:products, []) |> assign(:cursor, nil) |> assign(:has_more, true) |> assign(:cart, []) |> assign(:selected_customer, nil)
    {:noreply, load_products(socket)}
  end

  def handle_event("add_product", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.products, &(to_string(&1.id) == id)) do
      nil -> {:noreply, socket}
      product -> {:noreply, socket |> add_product(product) |> sync() |> push_event("pos:cart-bump", %{id: id})}
    end
  end

  def handle_event("increase_quantity", %{"id" => id}, socket), do: {:noreply, change_quantity(socket, id, 1)}
  def handle_event("decrease_quantity", %{"id" => id}, socket), do: {:noreply, change_quantity(socket, id, -1)}

  def handle_event("set_quantity", %{"id" => id, "value" => value}, socket) do
    quantity = case Integer.parse(value) do {number, _} -> number; :error -> 0 end
    {:noreply, set_quantity(socket, id, quantity)}
  end

  def handle_event("remove_line", %{"id" => id}, socket), do: {:noreply, socket |> assign(:cart, Enum.reject(socket.assigns.cart, &(to_string(&1.id) == id))) |> sync()}
  def handle_event("clear_sale_prompt", _, socket), do: {:noreply, assign(socket, :dialog, :clear_sale)}
  def handle_event("clear_sale", _, socket), do: {:noreply, socket |> assign(:cart, []) |> assign(:order_discount, 0.0) |> assign(:delivery, 0.0) |> assign(:dialog, nil) |> sync()}
  def handle_event("close_dialog", _, socket), do: {:noreply, assign(socket, :dialog, nil)}

  def handle_event("open_line_discount", %{"id" => id}, socket) do
    cond do
      socket.assigns.order_discount > 0 ->
        {:noreply, put_flash(socket, :info, "An order discount is active. Remove it before applying an item discount.")}

      line = Enum.find(socket.assigns.cart, &(to_string(&1.id) == id)) ->
        {:noreply, socket |> assign(:dialog, :discount) |> assign(:discount_target, id) |> assign(:discount_type, line.discount_type) |> assign(:discount_input, discount_input_value(line.discount))}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("open_order_discount", _, socket) do
    if socket.assigns.cart == [] do
      {:noreply, socket}
    else
      {:noreply, socket |> assign(:dialog, :discount) |> assign(:discount_target, nil) |> assign(:discount_type, socket.assigns.order_discount_type) |> assign(:discount_input, discount_input_value(socket.assigns.order_discount))}
    end
  end

  def handle_event("open_order_discount_key", %{"key" => key}, socket) when key in ["Enter", " "], do: handle_event("open_order_discount", %{}, socket)
  def handle_event("open_order_discount_key", _, socket), do: {:noreply, socket}

  def handle_event("set_discount_type", %{"type" => type}, socket) when type in ["amount", "percent"], do: {:noreply, assign(socket, :discount_type, type)}
  def handle_event("change_discount", %{"value" => value}, socket), do: {:noreply, assign(socket, :discount_input, value)}
  def handle_event("clear_discount_input", _, socket), do: {:noreply, assign(socket, :discount_input, "")}
  def handle_event("clear_pos_flash", _, socket), do: {:noreply, clear_flash(socket, :info)}

  def handle_event("apply_discount", params, socket) do
    discount_type = Map.get(params, "discount_type", socket.assigns.discount_type)
    socket = assign(socket, :discount_type, discount_type)
    discount = float(Map.get(params, "value", socket.assigns.discount_input))
    valid? = discount_type in ["amount", "percent"] and discount >= 0 and (discount_type != "percent" or discount <= 100)
    if not valid?, do: {:noreply, put_flash(socket, :error, "Enter a valid discount.")}, else: {:noreply, apply_discount(socket, discount)}
  end

  def handle_event("open_customer_picker", _, socket), do: {:noreply, socket |> assign(:dialog, :customer_picker) |> load_customers()}
  def handle_event("search_customers", %{"value" => value}, socket), do: {:noreply, socket |> assign(:customer_search, value) |> load_customers()}
  def handle_event("select_customer", %{"id" => id}, socket), do: {:noreply, socket |> assign(:selected_customer, Enum.find(socket.assigns.customers, &(to_string(&1.id) == id))) |> assign(:dialog, nil)}
  def handle_event("clear_customer", _, socket), do: {:noreply, assign(socket, :selected_customer, nil)}
  def handle_event("open_checkout", _, socket) do
    if socket.assigns.cart == [] do
      {:noreply, put_flash(socket, :error, "Add a product before continuing.")}
    else
      {:noreply, assign(socket, :checkout_stage, if(socket.assigns.selected_customer, do: :payment, else: :customer))}
    end
  end
  def handle_event("close_checkout", _, socket), do: {:noreply, assign(socket, :checkout_stage, nil)}
  def handle_event("checkout_customer_continue", _, socket), do: {:noreply, assign(socket, :checkout_stage, :payment)}
  def handle_event("toggle_delivery", _, socket), do: {:noreply, socket |> assign(:delivery, if(socket.assigns.delivery > 0, do: 0.0, else: 100.0)) |> sync()}
  def handle_event("set_delivery", %{"amount" => amount}, socket), do: {:noreply, socket |> assign(:delivery, float(amount)) |> sync()}
  def handle_event("toggle_credit", _, socket), do: {:noreply, assign(socket, :credit, !socket.assigns.credit)}
  def handle_event("select_sequence", %{"sequence" => sequence}, socket) when sequence in ["CF", "VF", "DV"], do: {:noreply, assign(socket, :sequence, sequence)}
  def handle_event("change_memo", %{"value" => value}, socket), do: {:noreply, assign(socket, :memo, String.slice(value, 0, 1000))}
  def handle_event("add_payment_line", _, socket), do: {:noreply, socket |> assign(:payments, socket.assigns.payments ++ [%{id: "payment-#{System.unique_integer([:positive])}", type: "CASH", amount: remaining(socket)}]) |> sync()}
  def handle_event("remove_payment_line", %{"id" => id}, socket), do: {:noreply, socket |> assign(:payments, Enum.reject(socket.assigns.payments, &(&1.id == id))) |> sync()}
  def handle_event("change_payment", %{"id" => id, "field" => field, "value" => value}, socket), do: {:noreply, socket |> update_payment(id, field, value) |> sync()}
  def handle_event("open_mobile_cart", _, socket), do: {:noreply, assign(socket, :mobile_cart_open, true)}
  def handle_event("close_mobile_cart", _, socket), do: {:noreply, assign(socket, :mobile_cart_open, false)}

  def handle_event("complete_sale", _, socket) do
    if socket.assigns.selected_customer && (socket.assigns.credit || paid(socket) >= total(socket)) do
      attrs = %{"store_id" => socket.assigns.store_id, "client_id" => socket.assigns.selected_customer.id, "sequence_type" => socket.assigns.sequence, "status" => if(socket.assigns.credit, do: "CREDIT", else: "CASH"), "sale_type" => if(socket.assigns.delivery > 0, do: "FOR_DELIVER", else: "IN_SHOP"), "delivery_charge" => socket.assigns.delivery, "discount" => order_discount_total(socket), "discount_type" => discount_type_for_sale(socket), "discount_input" => socket.assigns.order_discount, "additional_info" => socket.assigns.memo, "lines" => Enum.map(socket.assigns.cart, &%{"product_id" => &1.id, "quantity" => &1.qty, "discount" => line_discount(&1), "discount_type" => if(&1.discount_type == "percent", do: "percentage", else: "money"), "discount_input" => &1.discount}), "payments" => if(socket.assigns.credit, do: [], else: Enum.map(socket.assigns.payments, &%{"type" => &1.type, "amount" => &1.amount}))}
      case Sales.create_sale(socket.assigns.scope, attrs) do
        {:ok, _} -> {:noreply, socket |> put_flash(:info, "Sale completed.") |> assign(:cart, []) |> assign(:checkout_stage, nil) |> assign(:selected_customer, nil) |> assign(:order_discount, 0.0) |> assign(:delivery, 0.0) |> sync()}
        {:error, reason} -> {:noreply, put_flash(socket, :error, "Sale could not be completed: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Select a customer and cover the sale total before completing.")}
    end
  end

  @impl true
  def render(assigns) do
    assigns = Map.put(assigns, :socket, assigns.pos_state)
    ~H"""
    <main id="pos-live" class="pos-shell" phx-hook="PosShell" data-mobile-cart-open={to_string(@mobile_cart_open)}>
      <div
        :if={message = Phoenix.Flash.get(@flash, :info)}
        id="toast-container"
        class="toast-container"
        data-position="bottom-right"
        aria-label="Notifications"
      >
        <div
          id="discount-order-active"
          class="toast"
          data-variant="info"
          popover="manual"
          phx-hook="FlashToast"
          role="status"
          aria-live="polite"
          aria-atomic="true"
        >
          <div class="toast-content">
            <svg class="toast-icon" aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>
            <div class="toast-text"><p class="toast-description">{message}</p></div>
            <button class="toast-close" type="button" phx-click="clear_pos_flash" aria-label="Dismiss notification">×</button>
          </div>
        </div>
      </div>
      <nav class="sidebar-rail" aria-label="Primary navigation">
        <a class="sidebar-link" href="#" aria-current="page" aria-label="POS"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3h18v18H3z"/><path d="M7 7h10v10H7z"/></svg></a>
        <button class="sidebar-link" type="button" aria-label="Customers"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg></button>
        <button class="sidebar-link" type="button" aria-label="Invoice report"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 2v20h16"/><path d="M8 6h8M8 10h8M8 14h5"/></svg></button>
        <button class="sidebar-link" type="button" aria-label="Inventory"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5M3 16l9 5 9-5"/></svg></button>
        <button class="sidebar-link" type="button" aria-label="Purchase orders"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 2h9l3 3v17H6z"/><path d="M9 10h6M9 14h6"/></svg></button>
        <details class="sidebar-menu sidebar-store-selector"><summary class="sidebar-menu-trigger" aria-label="Choose active store">⌂</summary><div class="user-menu-content sidebar-menu-content" role="group" aria-label="Active store"><button :for={store <- @stores} class="sidebar-menu-action" type="button" phx-click="change_store" phx-value-store_id={store.id} aria-pressed={to_string(store.id == @store_id)}>{store.name}</button></div></details>
        <details class="sidebar-menu sidebar-theme-selector"><summary class="sidebar-menu-trigger" aria-label="Choose theme">◐</summary><div class="user-menu-content sidebar-menu-content"><button class="sidebar-menu-action" type="button" phx-click={JS.dispatch("pos:set-theme", detail: %{theme: "default-light"})}>Default Light</button></div></details>
      </nav>
      <div class="status-strip" aria-label="System status">
        <span class="session-store-status" aria-live="polite">{@scope.login}</span>
        <details class="language-switcher"><summary aria-label="Change display language"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 3.7 5.5 3.7 9S14.5 18.5 12 21c-2.5-2.5-3.7-5.5-3.7-9S9.5 5.5 12 3Z"/></svg></summary><div class="language-menu" role="group"><button type="button">English</button><button type="button">Español</button><button type="button">Português</button></div></details>
        <svg class="printer-status connected" role="img" aria-label="Printer available" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9V3h12v6"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 14h12v7H6z"/></svg>
        <svg class="network-status" role="img" aria-label="Network status available" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h.01"/><path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/></svg>
      </div>
      <section class="catalog-panel" aria-labelledby="pos-title" inert={if @mobile_cart_open, do: true}>
        <div :if={is_nil(@checkout_stage)} class="catalog-content">
          <header class="topbar"><div class="brand-lockup"><span class="brand-mark">T</span><div><p class="eyebrow">Tigoo</p><h1 id="pos-title">Point of Sale — {active_store_name(assigns)}</h1></div></div><button class="btn mobile-topbar-cart" type="button" phx-click="open_mobile_cart" aria-label="Open current sale">🛒<span :if={items(assigns) > 0} class="mobile-cart-count">{items(assigns)}</span></button><div class="topbar-search"><div class="search-field"><svg class="search-icon" aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="11" cy="11" r="6"/><path d="m16 16 4 4"/></svg><input id="product-search" class="input" type="search" value={@product_search} phx-keyup="search_products" phx-debounce="0" placeholder="Search products or scan a barcode" autocomplete="off"/><button :if={@product_search != ""} class="btn search-clear" type="button" phx-click="clear_product_search">×</button></div><button class="btn" type="button" data-variant="outline" data-size="icon" phx-click={JS.focus(to: "#product-search")} aria-label="Focus product search">⌕</button></div></header>
          <div class="catalog-heading"><div><p class="eyebrow">Catalog</p><h2 class="h3">Products</h2></div><p class="products-status" role="status">{product_status(assigns)}</p></div>
          <button class="btn mobile-cart-trigger" type="button" phx-click="open_mobile_cart">View sale</button>
          <div id="product-grid" class="product-grid" aria-live="polite">
            <article :for={product <- visible_products(assigns)} class="card product" tabindex="0" role="button" phx-click="add_product" phx-value-id={product.id} phx-keydown="add_product" phx-key="Enter" phx-value-id={product.id} aria-label={"Add #{product.name}"}>
              <img :if={product.image_raw} class="product-image" src={image_source(product.image_raw)} alt="" loading="lazy"/>
              <div :if={!product.image_raw} class="product-image product-image-placeholder" aria-hidden="true">{String.first(product.name || "?")}</div>
              <div class="card-content product-content"><h2 class="card-title product-name">{product.name || "Unnamed product"}</h2><p class="product-code">{if product.code, do: "SKU #{product.code}", else: "Tap to add"}</p><div class="product-footer"><strong class="product-price numeric">{money(float(product.price))}</strong><span class={["inventory-badge", if(float(product.inventory_quantity) <= 0, do: "inventory-badge-low")]}>Stock {product.inventory_quantity || 0}</span></div></div>
            </article>
            <article :for={_ <- if(@loading_products and @products == [], do: 1..8, else: [])} class="card product product-skeleton-card"><div class="skeleton product-skeleton-image"></div><div class="card-content product-content"><i class="skeleton skeleton-line"></i><i class="skeleton skeleton-line"></i></div></article>
          </div>
          <div id="products-sentinel" phx-hook="InfiniteCatalog" aria-hidden="true"></div>
        </div>
        <section :if={@checkout_stage} id="checkout-flow" class="checkout-flow" aria-live="polite">
          <header class="checkout-header"><div><p class="eyebrow">Checkout</p><h1 class="h3">{if @checkout_stage == :customer, do: "Select customer", else: "Payment & completion"}</h1></div><button class="btn" type="button" data-variant="outline" phx-click="close_checkout">Back to sale</button></header>
          <ol class="checkout-steps"><li aria-current={if @checkout_stage == :customer, do: "step"}>1. Customer</li><li aria-current={if @checkout_stage == :payment, do: "step"}>2. Payment</li></ol>
          <section :if={@checkout_stage == :customer} class="checkout-stage"><div class="checkout-stage-copy"><p class="eyebrow">1. Customer</p><h2 class="h2">Customer</h2><button class="customer-choice btn" type="button" data-variant="outline" phx-click="open_customer_picker">{(@selected_customer && @selected_customer.name) || "Pick a customer…"}</button><div :if={@selected_customer} class="customer-details">{@selected_customer.name} · {@selected_customer.celphone || ""} · {@selected_customer.address || ""}</div></div><div class="checkout-actions"><button class="btn" type="button" data-variant="outline" phx-click="close_checkout">Back</button><button class="btn" type="button" data-variant="default" phx-click="checkout_customer_continue" disabled={is_nil(@selected_customer)}>Continue</button></div></section>
          <section :if={@checkout_stage == :payment} class="checkout-stage"><div class="checkout-stage-copy"><p class="eyebrow">2. Payment</p><h2 class="h2">Payment & completion</h2><p class="checkout-total-due">Total due <strong class="numeric">{money(total(@socket))}</strong></p><div class="form-group checkout-payment"><button class="btn" type="button" data-variant={if @delivery > 0, do: "default", else: "outline"} phx-click="toggle_delivery">Delivery</button><div :if={@delivery > 0} class="delivery-options"><button :for={amount <- [100, 150, 200, 250, 300, 400, 500, 600]} class="btn" type="button" data-variant={if @delivery == amount, do: "default", else: "secondary"} phx-click="set_delivery" phx-value-amount={amount}>{money(amount)}</button></div><button class="btn" type="button" data-variant={if @credit, do: "default", else: "outline"} phx-click="toggle_credit">Pay on Credit</button><div :if={!@credit} id="payment-inputs"><fieldset class="form-fieldset"><legend>Sequence type</legend><div class="sequence-options"><button :for={sequence <- ["CF", "VF", "DV"]} class="btn" type="button" data-variant={if @sequence == sequence, do: "default", else: "secondary"} phx-click="select_sequence" phx-value-sequence={sequence}>{sequence}</button></div></fieldset><fieldset class="form-fieldset"><legend>Payments</legend><div class="payment-lines"><div :for={payment <- @payments} class="payment-line"><select class="select" phx-change="change_payment" phx-value-id={payment.id} phx-value-field="type"><option value="CASH" selected={payment.type == "CASH"}>Cash</option><option value="CC" selected={payment.type == "CC"}>Credit Card</option></select><input class="input numeric" type="number" inputmode="decimal" min="0.01" step="0.01" value={payment.amount} phx-change="change_payment" phx-value-id={payment.id} phx-value-field="amount"/><button class="btn" type="button" data-variant="ghost" phx-click="remove_payment_line" phx-value-id={payment.id}>×</button></div></div><button class="btn" type="button" data-variant="outline" phx-click="add_payment_line">Add payment</button><p class="field-description">Remaining: {money(remaining(@socket))}</p><p :if={paid(@socket) > total(@socket)} class="payment-change">Change: {money(paid(@socket) - total(@socket))}</p></fieldset></div></div></div><div class="checkout-actions"><button class="btn checkout-back" type="button" data-variant="outline" phx-click="checkout_customer_continue">Back</button><button class="btn" type="button" data-variant="default" phx-click="complete_sale" disabled={!@credit && paid(@socket) < total(@socket)}>Complete</button></div><div class="form-group checkout-memo"><label class="label" for="sale-memo">Memo (optional)</label><textarea id="sale-memo" class="input" rows="3" maxlength="1000" phx-change="change_memo">{@memo}</textarea><p class="field-description">Up to 1000 characters.</p></div></section>
        </section>
      </section>
      <aside id="order-panel" class={["order-panel", if(@mobile_cart_open, do: "is-mobile-open")]} phx-hook="CartAmounts" data-order-discount={@order_discount} data-order-discount-type={@order_discount_type} data-delivery={@delivery} aria-labelledby="order-title">
        <header class="order-header">
          <div><p class="eyebrow">Current sale</p><div class="customer-picker-wrap"><button id="order-title" class="customer-picker" type="button" phx-click="open_customer_picker">{(@selected_customer && @selected_customer.name) || "Pick a customer …"}</button><button :if={@selected_customer} id="clear-customer" class="btn" type="button" data-variant="ghost" data-size="icon-xs" phx-click="clear_customer" aria-label="Clear customer">×</button></div></div>
          <button class="btn mobile-cart-close" type="button" data-variant="ghost" data-size="icon" phx-click="close_mobile_cart" aria-label="Close sale">×</button>
          <button id="clear-order" class="btn" type="button" data-variant="ghost" data-size="sm" phx-click="clear_sale_prompt" disabled={@cart == []}>Clear</button>
        </header>
        <p :if={@cart == []} class="cart-empty">Your order is empty. Select a product to begin.</p>
        <div id="cart" class="cart-lines" aria-live="polite">
          <article :for={line <- @cart} id={"cart-line-#{line.id}"} class="cart-line" data-cart-item-id={line.id} data-price={line.price} data-sub={line.sub} data-tax={line.tax} data-discount={line.discount} data-discount-type={line.discount_type}>
            <div class="cart-line-head"><div><p class="cart-line-name" title={line.name}>{line.name}<span :if={line.discount > 0} class="line-discount">{if line.discount_type == "percent", do: "#{line.discount}%", else: money(line.discount)} off</span></p><p class="cart-line-breakdown"><span><small>Sub</small><strong class="numeric">{money(line.sub * line_factor(line))}</strong></span><span><small>Tax</small><strong class="numeric">{money(line.tax * line_factor(line))}</strong></span><span><small>Total</small><strong class="numeric">{money(line.price * line_factor(line))}</strong><small>each</small></span></p></div><button class="btn remove-line" type="button" data-variant="ghost" data-size="icon-xs" phx-click="remove_line" phx-value-id={line.id} aria-label={"Remove #{line.name}"}>×</button></div>
            <div class="cart-line-footer"><div class="quantity-control" role="group"><button class="btn" type="button" data-variant="outline" data-size="icon-xs" phx-click="decrease_quantity" phx-value-id={line.id} aria-label="Decrease quantity">−</button><input class="quantity-input" type="number" inputmode="numeric" min="1" value={line.qty} phx-change="set_quantity" phx-value-id={line.id} aria-label="Item count"/><button class="btn" type="button" data-variant="outline" data-size="icon-xs" phx-click="increase_quantity" phx-value-id={line.id} aria-label="Increase quantity">+</button></div><strong class="cart-line-total numeric">{money(line_gross(line) - line_discount(line))}</strong></div>
          </article>
        </div>
        <footer class="order-summary"><hr class="separator" role="none"/><dl class="totals"><div><dt>Items</dt><dd>{items(@socket)}</dd></div><div><dt>Subtotal</dt><dd class="numeric">{money(subtotal(@socket))}</dd></div><div><dt>Tax (18%)</dt><dd class="numeric">{money(tax(@socket))}</dd></div><div><dt>Discount</dt><dd class="numeric discount-value">−{money(line_discount_total(@socket) + order_discount_total(@socket))}</dd></div><div :if={@delivery > 0}><dt>Delivery</dt><dd class="numeric">{money(@delivery)}</dd></div><div class="grand-total" role="button" tabindex="0" phx-click="open_order_discount" phx-keydown="open_order_discount_key" aria-label="Apply order discount. Double click or press Enter."><dt>Total</dt><dd class="numeric">{money(total(@socket))}</dd></div></dl><div class="payment-label"><span>Payment method</span><span class="payment-choice">—</span></div><button class="btn charge-button" type="button" data-variant="default" data-size="lg" phx-click="open_checkout" disabled={@cart == []}>Continue</button></footer>
      </aside>
      <button :if={@mobile_cart_open} class="mobile-cart-backdrop is-visible" type="button" phx-click="close_mobile_cart" aria-label="Close sale"></button>
      <dialog :if={@dialog == :clear_sale} open class="dialog" data-size="sm"><div class="dialog-content"><div class="dialog-header"><h2 class="dialog-title">Clear this order?</h2><p class="dialog-description">All items and line discounts will be removed.</p></div><div class="dialog-footer"><button class="btn" type="button" data-variant="outline" phx-click="close_dialog">Cancel</button><button class="btn" type="button" data-variant="destructive" phx-click="clear_sale">Clear order</button></div></div></dialog>
      <dialog :if={@dialog == :discount} id="discount-dialog" class="dialog" data-size="sm" phx-hook="DiscountDialog" role="dialog" aria-modal="true" aria-labelledby="discount-title">
        <div class="dialog-content">
          <div class="dialog-header"><div class="discount-heading"><div><p class="eyebrow">{if @discount_target, do: "Line item discount", else: "Order discount"}</p><h2 id="discount-title" class="dialog-title">{if @discount_target, do: "Apply a discount", else: "Apply an order discount"}</h2><p class="dialog-description">{discount_subject(assigns)}</p></div><img :if={discount_image(assigns)} class="discount-product-image" src={discount_image(assigns)} alt=""/></div></div>
          <form id="discount-form" class="form" phx-hook="DiscountPreview" phx-submit="apply_discount" data-discount-base={discount_base(assigns)} data-discount-type={@discount_type}>
            <input id="discount-type" name="discount_type" type="hidden" value={@discount_type}/><div class="discount-switch" role="group" aria-label="Discount type"><button class="btn" type="button" data-discount-type="percent" data-variant={if @discount_type == "percent", do: "default", else: "secondary"} aria-pressed={to_string(@discount_type == "percent")}>%</button><button class="btn" type="button" data-discount-type="amount" data-variant={if @discount_type == "amount", do: "default", else: "secondary"} aria-pressed={to_string(@discount_type == "amount")}>$</button></div>
            <div class="form-field"><label id="discount-input-label" class="label" for="discount-input">{if @discount_type == "percent", do: "Discount percentage", else: "Discount amount"}</label><div class="form-field-inline"><input id="discount-input" class="input numeric" style="flex: 1" name="value" type="number" inputmode="decimal" min="0" max={if @discount_type == "percent", do: "100"} step="0.01" value={@discount_input}/><button class="btn" type="button" data-variant="outline" data-clear-discount>Clear</button></div><p id="discount-help" class="field-description">{if @discount_type == "percent", do: "Enter 0 to remove this item discount.", else: "The amount applies to this entire order line."}</p></div>
            <dl class="discount-preview"><div><dt>Amount</dt><dd class="numeric">{money(discount_base(assigns))}</dd></div><div><dt>Discount</dt><dd class="numeric">−{money(discount_preview(assigns))}</dd></div><div><dt>After discount</dt><dd class="numeric">{money(discount_base(assigns) - discount_preview(assigns))}</dd></div></dl>
            <div class="dialog-footer"><button class="btn" type="button" data-variant="outline" phx-click="close_dialog">Cancel</button><button class="btn" type="submit" data-variant="default">Apply discount</button></div>
          </form>
        </div>
      </dialog>
      <dialog :if={@dialog == :customer_picker} open class="dialog" data-size="sm"><div class="dialog-content"><div class="dialog-header"><h2 class="dialog-title">Select customer</h2><p class="dialog-description">Choose the customer for this sale.</p></div><input class="input" type="search" value={@customer_search} phx-keyup="search_customers" placeholder="Search customers by name or phone"/><div class="pos-customer-list"><button :for={customer <- @customers} class="pos-customer-row" type="button" phx-click="select_customer" phx-value-id={customer.id}><strong>{customer.name}</strong><small>{customer.celphone || customer.document_id || ""}</small></button><p :if={@customers == []}>No customers found.</p></div><div class="dialog-footer"><button class="btn" type="button" data-variant="outline" phx-click="close_dialog">Cancel</button></div></div></dialog>
    </main>
    """
  end

  defp load_products(%{assigns: %{loading_products: true}} = socket), do: socket
  defp load_products(%{assigns: %{has_more: false}} = socket), do: socket
  defp load_products(socket) do
    assign(socket, :loading_products, true)
    case Sql.active_products_page(socket.assigns.cursor, store_id: socket.assigns.store_id, limit: 100) do
      {:ok, page} ->
        socket
        |> assign(:products, socket.assigns.products ++ Enum.map(page.entries, &normalize_product/1))
        |> assign(:cursor, page.next_cursor)
        |> assign(:has_more, page.has_more?)
        |> assign(:loading_products, false)
      {:error, _} -> socket |> assign(:loading_products, false) |> put_flash(:error, "Products could not be loaded.")
    end
  end
  defp load_customers(socket) do
    case Sql.recent_clients_page(nil, socket.assigns.customer_search, limit: 100) do
      {:ok, page} -> assign(socket, :customers, Enum.map(page.entries, &normalize_customer/1))
      _ -> assign(socket, :customers, [])
    end
  end
  defp add_product(socket, p) do
    cart = case Enum.find_index(socket.assigns.cart, &(&1.id == p.id)) do
      nil -> socket.assigns.cart ++ [%{id: p.id, name: p.name || "Unnamed product", price: float(p.price), sub: float(p.sub), tax: float(p.tax), image_raw: p.image_raw, qty: 1, discount: 0.0, discount_type: "amount"}]
      index -> List.update_at(socket.assigns.cart, index, &Map.update!(&1, :qty, fn qty -> qty + 1 end))
    end
    assign(socket, :cart, cart)
  end
  defp change_quantity(socket, id, delta), do: Enum.find(socket.assigns.cart, &(to_string(&1.id) == id)) |> then(fn line -> if line, do: set_quantity(socket, id, line.qty + delta), else: socket end)
  defp set_quantity(socket, id, qty), do: if(qty < 1, do: assign(socket, :cart, Enum.reject(socket.assigns.cart, &(to_string(&1.id) == id))) |> sync(), else: assign(socket, :cart, Enum.map(socket.assigns.cart, fn line -> if to_string(line.id) == id, do: %{line | qty: qty}, else: line end)) |> sync())
  defp apply_discount(socket, value) do
    discount_target = socket.assigns.discount_target
    socket = if socket.assigns.discount_target do
      assign(socket, :cart, Enum.map(socket.assigns.cart, fn line -> if(to_string(line.id) == socket.assigns.discount_target, do: %{line | discount: value, discount_type: socket.assigns.discount_type}, else: line) end))
    else
      socket |> assign(:order_discount, value) |> assign(:order_discount_type, socket.assigns.discount_type) |> assign(:cart, Enum.map(socket.assigns.cart, &%{&1 | discount: 0.0, discount_type: "amount"}))
    end
    socket = socket |> assign(:dialog, nil) |> sync()
    if discount_target, do: push_event(socket, "pos:cart-bump", %{id: discount_target}), else: socket
  end
  defp update_payment(socket, id, "type", value), do: assign(socket, :payments, Enum.map(socket.assigns.payments, fn p -> if p.id == id, do: %{p | type: value}, else: p end))
  defp update_payment(socket, id, "amount", value), do: assign(socket, :payments, Enum.map(socket.assigns.payments, fn p -> if p.id == id, do: %{p | amount: float(value)}, else: p end))
  defp update_payment(socket, _, _, _), do: socket
  defp line_gross(line), do: line.price * line.qty
  defp line_discount(line), do: if(line.discount_type == "percent", do: line_gross(line) * min(line.discount, 100) / 100, else: min(line.discount, line_gross(line)))
  defp line_factor(line), do: if(line_gross(line) == 0, do: 1, else: (line_gross(line) - line_discount(line)) / line_gross(line))
  defp subtotal(state), do: Enum.sum(Enum.map(state(state).cart, fn line -> line.sub * line.qty * line_factor(line) * order_factor(state) end))
  defp line_discount_total(state), do: Enum.sum(Enum.map(state(state).cart, &line_discount/1))
  defp gross_subtotal(state), do: Enum.sum(Enum.map(state(state).cart, &line_gross/1))
  defp before_order_discount(state), do: gross_subtotal(state) - line_discount_total(state)
  defp order_discount_total(state), do: if(state(state).order_discount_type == "percent", do: before_order_discount(state) * min(state(state).order_discount, 100) / 100, else: min(state(state).order_discount, before_order_discount(state)))
  defp discount_type_for_sale(state), do: if(state(state).order_discount_type == "percent", do: "percentage", else: "money")
  defp total(state), do: before_order_discount(state) - order_discount_total(state) + state(state).delivery
  defp order_factor(state), do: if(before_order_discount(state) == 0, do: 1, else: total(state) / before_order_discount(state))
  defp tax(state), do: Enum.sum(Enum.map(state(state).cart, fn line -> line.tax * line.qty * line_factor(line) * order_factor(state) end))
  defp items(state), do: Enum.sum(Enum.map(state(state).cart, & &1.qty))
  defp paid(state), do: Enum.sum(Enum.map(state(state).payments, & &1.amount))
  defp remaining(socket), do: max(0.0, total(socket) - paid(socket))
  defp float(value) when is_number(value), do: value * 1.0
  defp float(%Decimal{} = value), do: Decimal.to_float(value)
  defp float(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _remainder} -> number
      :error -> 0.0
    end
  end
  defp float(_), do: 0.0
  defp discount_input_value(value) when value == 0 or value == 0.0, do: ""
  defp discount_input_value(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp money(value) do
    value = Float.round(value * 1.0, 2)
    [whole, cents] = :erlang.float_to_binary(value, decimals: 2) |> String.split(".")
    "$#{whole |> String.reverse() |> String.graphemes() |> Enum.chunk_every(3) |> Enum.map_join(",", &Enum.join(&1)) |> String.reverse()}.#{cents}"
  end
  defp visible_products(assigns) do
    query = String.downcase(String.trim(assigns.product_search))
    if query == "", do: assigns.products, else: Enum.filter(assigns.products, fn product -> String.contains?(String.downcase("#{product.name || ""} #{product.code || ""}"), query) end)
  end
  defp product_status(assigns) do
    cond do
      assigns.loading_products and assigns.products == [] -> "Loading products…"
      assigns.product_search != "" and visible_products(assigns) == [] -> "No matching products."
      assigns.has_more -> "Scroll for more products"
      true -> "#{length(assigns.products)} products loaded"
    end
  end
  defp image_source("data:image/" <> _ = source), do: source
  defp image_source(source), do: "data:image/jpeg;base64,#{source}"
  defp active_store_name(assigns), do: Enum.find_value(assigns.stores, "", fn store -> if store.id == assigns.store_id, do: store.name end)
  defp discount_line(assigns), do: Enum.find(assigns.cart, &(to_string(&1.id) == assigns.discount_target))
  defp discount_image(assigns) do
    case discount_line(assigns) do
      %{image_raw: image} when is_binary(image) -> image_source(image)
      _ -> nil
    end
  end

  defp discount_subject(assigns) do
    case discount_line(assigns) do
      %{name: name} -> name
      _ -> "Choose a percentage or amount for this order."
    end
  end

  defp discount_base(assigns) do
    case discount_line(assigns) do
      nil -> before_order_discount(assigns)
      line -> line_gross(line)
    end
  end
  defp discount_preview(assigns) do
    entered = float(assigns.discount_input)
    base = discount_base(assigns)
    if assigns.discount_type == "percent", do: base * min(entered, 100) / 100, else: min(entered, base)
  end

  defp normalize_product(product) do
    %{
      id: value(product, :id),
      name: value(product, :name),
      code: value(product, :code),
      image_raw: value(product, :image_raw),
      inventory_quantity: value(product, :inventory_quantity),
      price: value(product, :price),
      sub: value(product, :sub),
      tax: value(product, :tax)
    }
  end

  defp normalize_customer(customer) do
    %{
      id: value(customer, :id),
      name: value(customer, :name),
      celphone: value(customer, :celphone),
      address: value(customer, :address),
      document_id: value(customer, :document_id)
    }
  end

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp state(%{assigns: assigns}), do: assigns
  defp state(assigns), do: assigns
  defp sync(socket), do: assign(socket, :pos_state, Map.drop(socket.assigns, [:pos_state]))
end
