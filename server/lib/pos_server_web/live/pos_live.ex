defmodule PosServerWeb.PosLive do
  use PosServerWeb, :live_view

  import PosServerWeb.CustomerComponents
  import PosServerWeb.PosLayoutComponents

  alias PosServer.{Authentication, InventoryEvents, Repo, TenantContext}
  alias PosServer.Retaily.{Client, InventoryContext, Sales, Sql}

  @impl true
  def mount(_params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, scope} <- Authentication.authenticate(token),
         _tenant <- TenantContext.put_tenant(scope.tenant),
         {:ok, stores} <- InventoryContext.stores(scope) do
      store = selected_store(stores, session["store_id"])

      socket =
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
        |> assign(:customer_purchases, [])
        |> assign(:customer_dialog?, false)
        |> assign(:customer_form_status, "")
        |> assign(:saving_customer?, false)
        |> assign(:expanded_purchases, MapSet.new())
        |> assign(:checkout_stage, nil)
        |> assign(:dialog, nil)
        |> assign(:discount_target, nil)
        |> assign(:discount_type, "amount")
        |> assign(:discount_input, "0")
        |> assign(:order_discount, 0.0)
        |> assign(:order_discount_type, "amount")
        |> assign(:delivery, 0.0)
        |> assign(:delivery_open, false)
        |> assign(:delivery_custom_input, "")
        |> assign(:delivery_custom_selected, false)
        |> assign(:credit, false)
        |> assign(:credit_due_date, "")
        |> assign(:payments, [])
        |> assign(:sequence, "CF")
        |> assign(:memo, "")
        |> assign(:print_prompt, nil)
        |> assign(:mobile_cart_open, false)
        |> load_products()
        |> sync()

      if connected?(socket) and store, do: InventoryEvents.subscribe(scope.tenant, store.id)
      {:ok, socket}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Sign in is required to use POS.")
         |> redirect(to: ~p"/pos/login")}
    end
  end

  @impl true
  def handle_event("search_products", %{"value" => value}, socket),
    do: {:noreply, assign(socket, :product_search, value)}

  def handle_event("clear_product_search", _, socket),
    do: {:noreply, assign(socket, :product_search, "")}

  def handle_event("load_more_products", _, socket), do: {:noreply, load_products(socket)}

  def handle_event("change_store", %{"store_id" => id}, socket) do
    with {store_id, ""} <- Integer.parse(id),
         true <- Enum.any?(socket.assigns.stores, &(&1.id == store_id)),
         {:ok, _} <- InventoryContext.authorize_store(socket.assigns.scope, store_id) do
      InventoryEvents.unsubscribe(socket.assigns.scope.tenant, socket.assigns.store_id)
      InventoryEvents.subscribe(socket.assigns.scope.tenant, store_id)

      socket =
        socket
        |> assign(:store_id, store_id)
        |> assign(:products, [])
        |> assign(:cursor, nil)
        |> assign(:has_more, true)
        |> assign(:cart, [])
        |> assign(:selected_customer, nil)
        |> sync()

      {:noreply, load_products(socket)}
    else
      _ -> {:noreply, put_flash(socket, :error, "The selected store is unavailable.")}
    end
  end

  def handle_event("add_product", _params, %{assigns: %{checkout_stage: stage}} = socket)
      when not is_nil(stage),
      do: {:noreply, socket}

  def handle_event("add_product", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.products, &(to_string(&1.id) == id)) do
      nil ->
        {:noreply, socket}

      product ->
        {:noreply,
         socket |> add_product(product) |> sync() |> push_event("pos:cart-bump", %{id: id})}
    end
  end

  def handle_event(event, _params, %{assigns: %{checkout_stage: stage}} = socket)
      when event in ["increase_quantity", "decrease_quantity", "set_quantity", "remove_line"] and
             not is_nil(stage),
      do: {:noreply, socket}

  def handle_event("increase_quantity", %{"id" => id}, socket),
    do: {:noreply, change_quantity(socket, id, 1)}

  def handle_event("decrease_quantity", %{"id" => id}, socket),
    do: {:noreply, change_quantity(socket, id, -1)}

  def handle_event("set_quantity", %{"id" => id, "value" => value}, socket) do
    quantity =
      case Integer.parse(value) do
        {number, _} -> number
        :error -> 0
      end

    {:noreply, set_quantity(socket, id, quantity)}
  end

  def handle_event("remove_line", %{"id" => id}, socket),
    do:
      {:noreply,
       socket
       |> assign(:cart, Enum.reject(socket.assigns.cart, &(to_string(&1.id) == id)))
       |> sync()}

  def handle_event("clear_sale_prompt", _, socket),
    do: {:noreply, assign(socket, :dialog, :clear_sale)}

  def handle_event("clear_sale", _, socket),
    do:
      {:noreply,
       socket
       |> assign(:cart, [])
       |> assign(:order_discount, 0.0)
      |> assign(:delivery, 0.0)
      |> assign(:delivery_open, false)
      |> assign(:delivery_custom_input, "")
      |> assign(:delivery_custom_selected, false)
      |> assign(:credit, false)
      |> assign(:credit_due_date, "")
      |> assign(:payments, [])
      |> assign(:sequence, "CF")
      |> assign(:memo, "")
      |> assign(:dialog, nil)
       |> sync()}

  def handle_event("close_dialog", _, socket), do: {:noreply, assign(socket, :dialog, nil)}

  def handle_event(
        "open_line_discount",
        _params,
        %{assigns: %{checkout_stage: :payment}} = socket
      ),
      do: {:noreply, socket}

  def handle_event("open_line_discount", %{"id" => id}, socket) do
    cond do
      socket.assigns.order_discount > 0 ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "An order discount is active. Remove it before applying an item discount."
         )}

      line = Enum.find(socket.assigns.cart, &(to_string(&1.id) == id)) ->
        {:noreply,
         socket
         |> assign(:dialog, :discount)
         |> assign(:discount_target, id)
         |> assign(:discount_type, line.discount_type)
         |> assign(:discount_input, discount_input_value(line.discount))}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("open_order_discount", _, %{assigns: %{checkout_stage: :payment}} = socket),
    do: {:noreply, socket}

  def handle_event("open_order_discount", _, socket) do
    if socket.assigns.cart == [] do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:dialog, :discount)
       |> assign(:discount_target, nil)
       |> assign(:discount_type, socket.assigns.order_discount_type)
       |> assign(:discount_input, discount_input_value(socket.assigns.order_discount))}
    end
  end

  def handle_event("open_order_discount_key", %{"key" => key}, socket) when key in ["Enter", " "],
    do: handle_event("open_order_discount", %{}, socket)

  def handle_event("open_order_discount_key", _, socket), do: {:noreply, socket}

  def handle_event("set_discount_type", %{"type" => type}, socket)
      when type in ["amount", "percent"],
      do: {:noreply, assign(socket, :discount_type, type)}

  def handle_event("change_discount", %{"value" => value}, socket),
    do: {:noreply, assign(socket, :discount_input, value)}

  def handle_event("clear_discount_input", _, socket),
    do: {:noreply, assign(socket, :discount_input, "")}

  def handle_event("clear_pos_flash", _, socket), do: {:noreply, clear_flash(socket, :info)}

  def handle_event("apply_discount", params, socket) do
    discount_type = Map.get(params, "discount_type", socket.assigns.discount_type)
    socket = assign(socket, :discount_type, discount_type)
    discount = float(Map.get(params, "value", socket.assigns.discount_input))

    valid? =
      discount_type in ["amount", "percent"] and discount >= 0 and
        (discount_type != "percent" or discount <= 100)

    if not valid?,
      do: {:noreply, put_flash(socket, :error, "Enter a valid discount.")},
      else: {:noreply, apply_discount(socket, discount)}
  end

  def handle_event("open_customer_picker", _, socket),
    do: {:noreply, socket |> assign(:dialog, :customer_picker) |> load_customers()}

  def handle_event("search_customers", %{"value" => value}, socket),
    do: {:noreply, socket |> assign(:customer_search, value) |> load_customers()}

  def handle_event("select_customer", %{"id" => id}, socket),
    do:
      {:noreply,
      socket
      |> assign(
        :selected_customer,
        Enum.find(socket.assigns.customers, &(to_string(&1.id) == id))
      )
      |> assign(:dialog, nil)
      |> sync()}

  def handle_event("clear_customer", _, %{assigns: %{checkout_stage: stage}} = socket)
      when not is_nil(stage),
      do: {:noreply, socket}

  def handle_event("clear_customer", _, socket),
    do: {:noreply, socket |> assign(:selected_customer, nil) |> sync()}

  def handle_event("open_customer_dialog", _, socket),
    do: {:noreply, socket |> assign(:customer_dialog?, true) |> assign(:customer_form_status, "")}

  def handle_event("close_customer_dialog", _, socket),
    do:
      {:noreply,
       socket
       |> assign(:customer_dialog?, false)
       |> assign(:customer_form_status, "")
       |> assign(:saving_customer?, false)}

  def handle_event("create_customer", params, socket) do
    attrs =
      params
      |> Map.put("wholesaler", wholesaler_value(params["is_wholesaler"]))
      |> Map.delete("is_wholesaler")

    case %Client{} |> Client.changeset(attrs) |> Repo.insert(prefix: TenantContext.tenant!()) do
      {:ok, customer} ->
        customer = normalize_customer(customer)

        {:noreply,
         socket
         |> assign(:customer_dialog?, false)
         |> assign(:customer_form_status, "")
         |> assign(:saving_customer?, false)
         |> assign(:selected_customer, customer)
         |> assign(:dialog, nil)
         |> load_customers()
         |> sync()}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(
           :customer_form_status,
           "Could not create customer. Check the data and try again."
         )
         |> assign(:saving_customer?, false)}
    end
  end

  def handle_event("open_customer_purchases", _, %{assigns: %{selected_customer: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("open_customer_purchases", _, socket) do
    customer = socket.assigns.selected_customer

    case Sales.recent_customer_purchases(socket.assigns.scope, customer.id) do
      {:ok, purchases} ->
        {:noreply,
         socket
         |> assign(:customer_purchases, purchases)
         |> assign(:expanded_purchases, MapSet.new())
         |> assign(:dialog, :customer_purchases)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Customer purchases could not be loaded.")}
    end
  end

  def handle_event("open_checkout", _, socket) do
    if socket.assigns.cart == [] do
      {:noreply, put_flash(socket, :error, "Add a product before continuing.")}
    else
      {:noreply,
       assign(
         socket,
         :checkout_stage,
         if(socket.assigns.selected_customer, do: :payment, else: :customer)
       )}
    end
  end

  def handle_event("close_checkout", _, socket),
    do: {:noreply, assign(socket, :checkout_stage, nil)}

  def handle_event("checkout_customer_continue", _, socket),
    do: {:noreply, assign(socket, :checkout_stage, :payment)}

  def handle_event("checkout_payment_back", _, socket),
    do: {:noreply, assign(socket, :checkout_stage, :customer)}

  def handle_event("toggle_delivery", _, socket) do
    socket = assign(socket, :delivery_open, !socket.assigns.delivery_open)
    socket =
      if socket.assigns.delivery_open,
        do: socket,
        else:
          socket
          |> assign(:delivery_custom_input, "")
          |> assign(:delivery_custom_selected, false)
          |> set_delivery_total(0.0)

    {:noreply, sync(socket)}
  end

  def handle_event("set_delivery", %{"amount" => amount}, socket),
    do:
      {:noreply,
       socket
       |> assign(:delivery_open, true)
       |> assign(:delivery_custom_selected, false)
       |> set_delivery_total(float(amount))
       |> sync()}

  def handle_event("change_delivery_amount", %{"value" => amount}, socket),
    do: {:noreply, change_custom_delivery_amount(socket, amount)}

  def handle_event("apply_custom_delivery", params, socket) do
    amount = Map.get(params, "value", socket.assigns.delivery_custom_input)
    amount = delivery_amount_input(amount)

    {:noreply,
     socket
     |> assign(:delivery_open, true)
     |> assign(:delivery_custom_input, amount)
     |> assign(:delivery_custom_selected, true)
     |> set_delivery_total(float(amount))
     |> sync()}
  end

  def handle_event("toggle_credit", _, socket) do
    credit = !socket.assigns.credit

    socket =
      socket
      |> assign(:credit, credit)
      |> assign(:credit_due_date, if(credit, do: socket.assigns.credit_due_date, else: ""))

    {:noreply, sync(socket)}
  end

  def handle_event("change_credit_due_date", %{"value" => value}, socket),
    do: {:noreply, socket |> assign(:credit_due_date, value) |> sync()}

  def handle_event("change_credit_due_date", %{"credit_due_date" => value}, socket),
    do: {:noreply, socket |> assign(:credit_due_date, value) |> sync()}

  def handle_event("select_sequence", %{"sequence" => sequence}, socket)
      when sequence in ["CF", "VF", "DV"],
      do: {:noreply, socket |> assign(:sequence, sequence) |> sync()}

  def handle_event("change_memo", %{"value" => value}, socket),
    do: {:noreply, socket |> assign(:memo, String.slice(value, 0, 1000)) |> sync()}

  def handle_event("restore_pos_draft", draft, socket) do
    {:noreply, restore_pos_draft(socket, draft)}
  end

  def handle_event("add_payment_line", _, socket) do
    previous = List.last(socket.assigns.payments)
    # Tauri's addPaymentLine defaults the first payment to Card and alternates
    # each following line from the preceding method.
    type = if previous && previous.type == "CC", do: "CASH", else: "CC"
    amount = Float.round(max(0.0, total(socket) - paid(socket)), 2)

    payment = %{
      id: "payment-#{System.unique_integer([:positive])}",
      type: type,
      amount: amount,
      split_source: previous && previous.id,
      auto_amount: true
    }

    {:noreply, socket |> assign(:payments, socket.assigns.payments ++ [payment]) |> sync()}
  end

  def handle_event("remove_payment_line", %{"id" => id}, socket),
    do:
      {:noreply,
       socket |> assign(:payments, Enum.reject(socket.assigns.payments, &(&1.id == id))) |> sync()}

  def handle_event("change_payment", %{"id" => id, "field" => field, "value" => value}, socket),
    do: {:noreply, socket |> update_payment(id, field, value) |> sync()}

  def handle_event("open_mobile_cart", _, socket),
    do: {:noreply, assign(socket, :mobile_cart_open, true)}

  def handle_event("close_mobile_cart", _, socket),
    do: {:noreply, assign(socket, :mobile_cart_open, false)}

  def handle_event("complete_sale", params, socket) do
    socket = assign_credit_due_date(socket, params)

    if socket.assigns.selected_customer &&
         payment_complete?(socket) do
      attrs = %{
        "store_id" => socket.assigns.store_id,
        "client_id" => socket.assigns.selected_customer.id,
        "sequence_type" => socket.assigns.sequence,
        "status" => if(socket.assigns.credit, do: "CREDIT", else: "CASH"),
        "due_date" => if(socket.assigns.credit, do: socket.assigns.credit_due_date, else: nil),
        "sale_type" => if(socket.assigns.delivery > 0, do: "FOR_DELIVER", else: "IN_SHOP"),
        "delivery_charge" => socket.assigns.delivery,
        "discount" => order_discount_total(socket),
        "discount_type" => discount_type_for_sale(socket),
        "discount_input" => socket.assigns.order_discount,
        "additional_info" => socket.assigns.memo,
        "lines" =>
          Enum.map(
            socket.assigns.cart,
            &%{
              "product_id" => &1.id,
              "quantity" => &1.qty,
              "discount" => line_discount(&1),
              "discount_type" =>
                if(&1.discount_type == "percent", do: "percentage", else: "money"),
              "discount_input" => &1.discount
            }
          ),
        "payments" =>
          if(socket.assigns.credit,
            do: [],
            else: Enum.map(socket.assigns.payments, &%{"type" => &1.type, "amount" => &1.amount})
          )
      }

      # Tauri retains a zero-valued split row in the checkout UI, but omits it
      # from the completed sale payload (`.filter(line => line.amount)`).
      # Keep that distinction: the Cash row remains visible until completion,
      # while persistence receives only actual payments.
      attrs =
        Map.update!(
          attrs,
          "payments",
          &Enum.filter(&1, fn payment -> float(payment["amount"]) > 0 end)
        )

      case Sales.create_sale(socket.assigns.scope, attrs) do
        {:ok, sale} ->
          receipt = receipt_payload(sale, current_store(socket))

          {:noreply,
           socket
           |> put_flash(:info, "Sale completed.")
           |> assign(:print_prompt, print_prompt(:receipt, receipt))
           |> assign(:cart, [])
           |> assign(:checkout_stage, nil)
           |> assign(:selected_customer, nil)
           |> assign(:order_discount, 0.0)
           |> assign(:delivery, 0.0)
           |> assign(:delivery_open, false)
           |> assign(:delivery_custom_input, "")
           |> assign(:delivery_custom_selected, false)
           |> assign(:credit, false)
           |> assign(:credit_due_date, "")
           |> assign(:payments, [])
           |> assign(:memo, "")
           |> sync()}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Sale could not be completed: #{inspect(reason)}")}
      end
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "Select a customer, cover the total, and choose a future due date for credit sales."
       )}
    end
  end

  def handle_event("printer_status", _params, socket), do: {:noreply, socket}

  def handle_event("printer_result", %{"status" => "success"}, socket),
    do: {:noreply, assign(socket, :print_prompt, nil)}

  def handle_event("printer_result", %{"message" => message}, socket),
    do: {:noreply, update_print_prompt(socket, "Print failed: #{message}", false)}

  def handle_event("printer_result", _params, socket),
    do: {:noreply, update_print_prompt(socket, "Print failed.", false)}

  def handle_event("skip_print", _params, socket),
    do: {:noreply, assign(socket, :print_prompt, nil)}

  def handle_event("confirm_print", _params, %{assigns: %{print_prompt: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("confirm_print", _params, socket) do
    prompt = socket.assigns.print_prompt

    {:noreply,
     socket
     |> update_print_prompt("Printing…", true)
     |> push_event(prompt.event, prompt.payload)}
  end

  @impl true
  def handle_info({:inventory_changed, %{product_ids: product_ids}}, socket) do
    {:noreply, refresh_inventory_products(socket, product_ids)}
  end

  @impl true
  def render(assigns) do
    # `@socket` is retained as a template-only compatibility alias. It must
    # reflect the current render assigns (not the previous sync snapshot), so
    # delivery changes recalculate checkout totals and payment balances at once.
    assigns = Map.put(assigns, :socket, assigns)

    ~H"""
    <.pos_layout
      id="pos-live"
      class="pos-shell"
      active_page={:pos}
      scope={@scope}
      stores={@stores}
      store_id={@store_id}
      phx-hook="PosShell"
      data-mobile-cart-open={to_string(@mobile_cart_open)}
      data-checkout-stage={@checkout_stage || ""}
    >
      <:before_layout>
        <svg class="navigation-icon-sprite" aria-hidden="true" focusable="false">
          <symbol
            id="ui-icon-search"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
          >
            <circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" />
          </symbol>
        </svg>
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
              <svg
                class="toast-icon"
                aria-hidden="true"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="12" cy="12" r="10" /><path d="M12 16v-4M12 8h.01" />
              </svg>
              <div class="toast-text">
                <p class="toast-description">{message}</p>
              </div>
              <button
                class="toast-close"
                type="button"
                phx-click="clear_pos_flash"
                aria-label="Dismiss notification"
              >
                ×
              </button>
            </div>
          </div>
        </div>
      </:before_layout>
      <section
        class="catalog-panel"
        aria-labelledby="pos-title"
        inert={if @mobile_cart_open, do: true}
      >
        <div :if={is_nil(@checkout_stage) and @dialog != :customer_picker} class="catalog-content">
          <header class="topbar">
            <div class="brand-lockup">
              <span class="brand-mark">T</span>
              <div>
                <p class="eyebrow">Tigoo</p>
                <h1 id="pos-title">Point of Sale — {active_store_name(assigns)}</h1>
              </div>
            </div>
            <button
              class="btn mobile-topbar-cart"
              type="button"
              phx-click="open_mobile_cart"
              aria-label="Open current sale"
            >
              🛒<span :if={items(assigns) > 0} class="mobile-cart-count">{items(assigns)}</span>
            </button>
            <div class="topbar-search">
              <div class="search-field">
                <svg class="search-icon" aria-hidden="true"><use href="#ui-icon-search" /></svg>
                <input
                  id="product-search"
                  class="input"
                  type="search"
                  value={@product_search}
                  phx-keyup="search_products"
                  phx-debounce="0"
                  placeholder="Search products or scan a barcode"
                  autocomplete="off"
                /><button
                  :if={@product_search != ""}
                  class="btn search-clear"
                  type="button"
                  phx-click="clear_product_search"
                >
                  ×
                </button>
              </div>
              <button
                class="btn"
                type="button"
                data-variant="outline"
                data-size="icon"
                phx-click={JS.focus(to: "#product-search")}
                aria-label="Focus product search"
              >
                <svg aria-hidden="true"><use href="#ui-icon-search" /></svg>
              </button>
            </div>
          </header>
          <div class="catalog-heading">
            <div>
              <p class="eyebrow">Catalog</p>
              <h2 class="h3">Products</h2>
            </div>
            <p class="products-status" role="status">{product_status(assigns)}</p>
          </div>
          <button class="btn mobile-cart-trigger" type="button" phx-click="open_mobile_cart">
            View sale
          </button>
          <div id="product-grid" class="product-grid" aria-live="polite">
            <article
              :for={product <- visible_products(assigns)}
              class="card product"
              tabindex="0"
              role="button"
              phx-click="add_product"
              phx-value-id={product.id}
              phx-keydown="add_product"
              phx-key="Enter"
              phx-value-id={product.id}
              aria-label={"Add #{product.name}"}
            >
              <img
                :if={product.image_raw}
                class="product-image"
                src={image_source(product.image_raw)}
                alt=""
                loading="lazy"
              />
              <div
                :if={!product.image_raw}
                class="product-image product-image-placeholder"
                aria-hidden="true"
              >
                {String.first(product.name || "?")}
              </div>
              <div class="card-content product-content">
                <h2 class="card-title product-name">{product.name || "Unnamed product"}</h2>
                <p class="product-code">
                  {if product.code, do: "SKU #{product.code}", else: "Tap to add"}
                </p>
                <div class="product-footer">
                  <strong class="product-price numeric">{money(float(product.price))}</strong><span class={[
                    "inventory-badge",
                    if(float(product.inventory_quantity) <= 0, do: "inventory-badge-low")
                  ]}>Stock {product.inventory_quantity || 0}</span>
                </div>
              </div>
            </article>
            <.product_skeleton_cards :if={@loading_products and @products == []} />
          </div>
          <div id="products-sentinel" phx-hook="InfiniteCatalog" aria-hidden="true"></div>
        </div>
        <section
          :if={@dialog == :customer_picker}
          id="customers-screen"
          class="customers-screen"
          aria-labelledby="customers-title"
        >
          <header class="topbar invoice-topbar customers-header">
            <div class="brand-lockup">
              <span class="brand-mark" aria-hidden="true">E</span>
              <div>
                <p class="eyebrow">Customers</p>
                <h2 id="customers-title" class="h3" tabindex="-1">Customer list</h2>
              </div>
            </div>
            <div class="customers-header-actions">
              <button
                id="create-customer"
                class="btn"
                type="button"
                data-variant="default"
                phx-click="open_customer_dialog"
                aria-haspopup="dialog"
              >
                Crear client
              </button><button
                class="btn"
                type="button"
                data-variant="outline"
                phx-click="close_dialog"
              >Back</button>
            </div>
          </header>
          <div class="customer-search-field">
            <label class="sr-only" for="customer-search">Search customers</label>
            <input
              id="customer-search"
              class="input"
              type="search"
              value={@customer_search}
              phx-keyup="search_customers"
              phx-debounce="220"
              phx-mounted={JS.focus(to: "#customer-search")}
              autocomplete="off"
              placeholder="Search customers by name or phone"
            />
          </div>
          <p :if={@customers == []} class="customers-status" role="status">No customers found.</p>
          <div class="table-container customer-table-container">
            <table class="table customer-table">
              <caption class="table-caption">Customer accounts and purchase activity.</caption>
              <thead>
                <tr class="table-row">
                  <th class="table-head" scope="col">Name</th>
                  <th class="table-head" scope="col">Document ID</th>
                  <th class="table-head" scope="col">Phone</th>
                  <th class="table-head" scope="col"><span class="sr-only">Customer action</span></th>
                </tr>
              </thead>
              <tbody id="customers-table-body">
                <tr :for={customer <- @customers} class="table-row">
                  <td class="table-cell" data-label="Name">{customer.name || "—"}</td>
                  <td class="table-cell" data-label="Document ID">{customer.document_id || "—"}</td>
                  <td class="table-cell" data-label="Phone">{customer.celphone || "—"}</td>
                  <td class="table-cell customer-action">
                    <button
                      class="btn"
                      type="button"
                      data-variant="outline"
                      data-size="sm"
                      phx-click="select_customer"
                      phx-value-id={customer.id}
                      aria-label={"Choose: #{customer.name || "customer"}"}
                    >
                      Choose
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
        <section
          :if={not is_nil(@checkout_stage) and @dialog != :customer_picker}
          id="checkout-flow"
          class="checkout-flow"
          aria-live="polite"
        >
          <header class="checkout-header">
            <div>
              <p class="eyebrow">Checkout</p>
              <h1 id="checkout-title" class="h3">
                {if @checkout_stage == :customer,
                  do: "Customer — #{active_store_name(assigns)}",
                  else: "Payment & completion — #{active_store_name(assigns)}"}
              </h1>
            </div>
            <button class="btn" type="button" data-variant="outline" phx-click="close_checkout">
              Back to sale
            </button>
          </header>
          <ol class="checkout-steps" aria-label="Checkout progress">
            <li aria-current={if @checkout_stage == :customer, do: "step"}>1. Customer</li>
            <li aria-current={if @checkout_stage == :payment, do: "step"}>2. Payment</li>
          </ol>
          <div class="checkout-stage-wrap">
            <section
              :if={@checkout_stage == :customer}
              class="checkout-stage"
              data-stage="customer"
              aria-labelledby="customer-stage-title"
            >
              <div class="checkout-stage-copy">
                <p class="eyebrow">1. Customer</p>
                <h2 id="customer-stage-title" class="h2" tabindex="-1">Customer</h2>
                <button
                  id="customer-picker"
                  class="customer-choice btn"
                  type="button"
                  data-variant="outline"
                  phx-click="open_customer_picker"
                >
                  {(@selected_customer && @selected_customer.name) || "Pick a customer…"}
                </button>
                <div :if={@selected_customer} id="customer-details" class="customer-details">
                  {@selected_customer.name} · {@selected_customer.celphone || ""} · {@selected_customer.address ||
                    ""}
                </div>
              </div>
              <div class="checkout-actions">
                <button class="btn" type="button" data-variant="outline" phx-click="close_checkout">
                  Back
                </button><button
                  id="customer-continue"
                  class="btn"
                  type="button"
                  data-variant="default"
                  phx-click="checkout_customer_continue"
                  disabled={is_nil(@selected_customer)}
                >Continue</button>
              </div>
            </section>
            <section
              :if={@checkout_stage == :payment}
              class="checkout-stage"
              data-stage="payment"
              aria-labelledby="payment-stage-title"
            >
              <div class="checkout-stage-copy">
                <p class="eyebrow">2. Payment</p>
                <h2 id="payment-stage-title" class="h2" tabindex="-1">Payment & completion</h2>
                <fieldset class="form-fieldset">
                  <legend>Sequence type</legend>
                  <div class="sequence-options" role="group">
                    <div class="sequence-option-buttons">
                      <button
                        :for={sequence <- ["CF", "DV", "VF"]}
                        class="btn"
                        type="button"
                        data-variant={if @sequence == sequence, do: "default", else: "secondary"}
                        phx-click="select_sequence"
                        phx-value-sequence={sequence}
                      >
                        {sequence}
                      </button>
                    </div>
                    <span class="sequence-option-description">
                      {sequence_description(@sequence)}
                    </span>
                  </div>
                </fieldset>
                <p class="checkout-total-due">
                  <span>Total</span><strong id="checkout-total" class="numeric">{money(total(@socket))}</strong>
                </p>
                <div class="form-group checkout-payment">
                  <button
                    id="delivery-toggle"
                    class="btn"
                    type="button"
                    data-variant={if @delivery_open, do: "default", else: "outline"}
                    aria-pressed={to_string(@delivery_open)}
                    phx-click="toggle_delivery"
                  >
                    Delivery
                  </button>
                  <div :if={@delivery_open} id="delivery-options" class="delivery-options">
                    <button
                      :for={amount <- [100, 150, 200]}
                      class="btn"
                      type="button"
                      data-variant={
                        if !@delivery_custom_selected and @delivery == amount,
                          do: "default",
                          else: "secondary"
                      }
                      phx-click="set_delivery"
                      phx-value-amount={amount}
                    >
                      {money(amount)}
                    </button>
                    <form
                      class="delivery-free-control"
                      role="group"
                      aria-label="Delivery free amount"
                      phx-submit="apply_custom_delivery"
                    >
                      <input
                        id="delivery-free-amount"
                        class="input delivery-free-amount"
                        type="number"
                        name="value"
                        min="0"
                        step="0.01"
                        inputmode="decimal"
                        placeholder="Free amount"
                        aria-label="Delivery free amount"
                        value={@delivery_custom_input}
                        required
                        phx-input="change_delivery_amount"
                        phx-debounce="300"
                      />
                      <button
                        class="btn delivery-free-check"
                        type="submit"
                        data-variant={if @delivery_custom_selected, do: "default", else: "secondary"}
                        aria-pressed={to_string(@delivery_custom_selected)}
                        aria-label="Select delivery free amount"
                      >✓</button>
                    </form>
                    <button
                      :for={amount <- [300, 400, 500, 600]}
                      class="btn"
                      type="button"
                      data-variant={
                        if !@delivery_custom_selected and @delivery == amount,
                          do: "default",
                          else: "secondary"
                      }
                      phx-click="set_delivery"
                      phx-value-amount={amount}
                    >
                      {money(amount)}
                    </button>
                  </div>
                  <button
                    id="credit-toggle"
                    class="btn"
                    type="button"
                    data-variant={if @credit, do: "default", else: "outline"}
                    aria-pressed={to_string(@credit)}
                    phx-click="toggle_credit"
                  >
                    Pay on Credit
                  </button>
                  <form
                    :if={@credit}
                    id="credit-due-date"
                    class="form-group"
                    phx-submit="complete_sale"
                    phx-hook="CreditDueDateForm"
                  >
                    <label class="label" for="sale-credit-due-date">Due date</label>
                    <input
                      id="sale-credit-due-date"
                      name="credit_due_date"
                      class="input"
                      type="date"
                      value={@credit_due_date}
                      min={future_due_date_min()}
                      required
                      phx-input="change_credit_due_date"
                      phx-change="change_credit_due_date"
                    />
                    <div class="checkout-actions">
                      <button
                        class="btn checkout-back"
                        type="button"
                        data-variant="outline"
                        phx-click="checkout_payment_back"
                      >
                        Back
                      </button><button
                        id="complete-sale"
                        class="btn"
                        type="submit"
                        data-variant="default"
                        disabled
                      >Complete</button>
                    </div>
                  </form>
                  <div :if={!@credit} id="payment-inputs">
                    <fieldset class="form-fieldset">
                      <legend>Payments</legend>
                      <div
                        id="payment-lines"
                        class="payment-lines"
                        phx-hook="PaymentAmounts"
                        data-sale-total={total(@socket)}
                      >
                        <div
                          :for={payment <- @payments}
                          class="payment-line"
                          data-payment-line-id={payment.id}
                          data-split-source={Map.get(payment, :split_source, "")}
                        >
                          <select
                            class="select"
                            phx-change="change_payment"
                            phx-value-id={payment.id}
                            phx-value-field="type"
                          >
                            <option value="CASH" selected={payment.type == "CASH"}>Cash</option>
                            <option value="CC" selected={payment.type == "CC"}>Credit Card</option>
                          </select>
                          <input
                            class="input numeric"
                            type="number"
                            inputmode="decimal"
                            min="0.01"
                            step="0.01"
                            value={payment_amount_input(payment.amount)}
                            data-previous-amount={payment_amount_input(payment.amount)}
                            phx-input="change_payment"
                            phx-value-id={payment.id}
                            phx-value-field="amount"
                          /><button
                            class="btn"
                            type="button"
                            data-variant="ghost"
                            phx-click="remove_payment_line"
                            phx-value-id={payment.id}
                            aria-label="Remove payment"
                          >
                            ×
                          </button>
                        </div>
                      </div>
                      <button
                        id="add-payment-line"
                        class="btn"
                        type="button"
                        data-variant="outline"
                        phx-click="add_payment_line"
                      >
                        Add payment
                      </button>
                      <p id="payment-balance" class="field-description">
                        Remaining: {money(remaining(@socket))}
                      </p>
                      <p
                        :if={paid(@socket) > total(@socket)}
                        id="payment-change"
                        class="payment-change"
                        role="status"
                      >
                        Change: {money(paid(@socket) - total(@socket))}
                      </p>
                    </fieldset>
                  </div>
                </div>
              </div>
              <div :if={!@credit} class="checkout-actions">
                <button
                  class="btn checkout-back"
                  type="button"
                  data-variant="outline"
                  phx-click="checkout_payment_back"
                >
                  Back
                </button><button
                  id="complete-sale"
                  class="btn"
                  type="button"
                  data-variant="default"
                  phx-click="complete_sale"
                  disabled={!payment_complete?(@socket)}
                >Complete</button>
              </div>
              <div class="form-group checkout-memo">
                <label class="label" for="sale-additional-info">Memo (optional)</label><textarea
                  id="sale-additional-info"
                  class="input"
                  rows="3"
                  maxlength="1000"
                  phx-change="change_memo"
                >{@memo}</textarea>
                <p class="field-description">Up to 1000 characters.</p>
              </div>
            </section>
          </div>
        </section>
      </section>
      <aside
        id="order-panel"
        class={["order-panel", if(@mobile_cart_open, do: "is-mobile-open")]}
        phx-hook="CartAmounts"
        data-order-discount={@order_discount}
        data-order-discount-type={@order_discount_type}
        data-delivery={@delivery}
        aria-labelledby="order-title"
      >
        <header class="order-header">
          <div>
            <p class="eyebrow">Current sale</p>
            <div class="customer-picker-wrap">
              <button
                :if={is_nil(@checkout_stage)}
                id="customer-purchases"
                class="btn"
                type="button"
                data-variant="ghost"
                data-size="icon-xs"
                phx-click="open_customer_purchases"
                aria-label="View customer purchases"
                aria-haspopup="dialog"
              >
                <svg
                  aria-hidden="true"
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M3 3v18h18" /><path d="M7 16v-4" /><path d="M12 16V8" /><path d="M17 16v-7" />
                </svg>
              </button><button
                id="order-title"
                class="customer-picker"
                type="button"
                phx-click="open_customer_picker"
                disabled={@checkout_stage == :payment}
              >{(@selected_customer && @selected_customer.name) || "Pick a customer …"}</button><button
                :if={@selected_customer && is_nil(@checkout_stage)}
                id="clear-customer"
                class="btn"
                type="button"
                data-variant="ghost"
                data-size="icon-xs"
                phx-click="clear_customer"
                aria-label="Clear customer"
              >×</button>
            </div>
          </div>
          <button
            class="btn mobile-cart-close"
            type="button"
            data-variant="ghost"
            data-size="icon"
            phx-click="close_mobile_cart"
            aria-label="Close sale"
          >
            ×
          </button>
          <button
            id="clear-order"
            class="btn"
            type="button"
            data-variant="ghost"
            data-size="sm"
            phx-click="clear_sale_prompt"
            disabled={@cart == []}
          >
            Clear
          </button>
        </header>
        <p :if={@cart == []} class="cart-empty">Your order is empty. Select a product to begin.</p>
        <div id="cart" class="cart-lines" aria-live="polite">
          <article
            :for={line <- @cart}
            id={"cart-line-#{line.id}"}
            class="cart-line"
            data-cart-item-id={line.id}
            data-price={line.price}
            data-sub={line.sub}
            data-tax={line.tax}
            data-discount={line.discount}
            data-discount-type={line.discount_type}
          >
            <div class="cart-line-head">
              <div>
                <p
                  class="cart-line-name cart-line-discount-trigger"
                  title="Apply a discount to this item"
                  role="button"
                  tabindex="0"
                  phx-click="open_line_discount"
                  phx-keydown="open_line_discount"
                  phx-value-id={line.id}
                >
                  {line.name}<span :if={line.discount > 0} class="line-discount">{if line.discount_type == "percent", do: "#{line.discount}%", else: money(line.discount)} off</span>
                </p>
                <p class="cart-line-breakdown">
                  <span>
                    <small>Sub</small><strong class="numeric">{money(line.sub * line_factor(line))}</strong>
                  </span><span><small>Tax</small><strong class="numeric">{money(line.tax * line_factor(line))}</strong></span><span><small>Total</small><strong class="numeric">{money(line.price * line_factor(line))}</strong><small>each</small></span>
                </p>
              </div>
              <button
                class="btn remove-line"
                type="button"
                data-variant="ghost"
                data-size="icon-xs"
                phx-click="remove_line"
                phx-value-id={line.id}
                aria-label={"Remove #{line.name}"}
                disabled={not is_nil(@checkout_stage)}
              >
                ×
              </button>
            </div>
            <div class="cart-line-footer">
              <div class="quantity-control" role="group">
                <button
                  class="btn"
                  type="button"
                  data-variant="outline"
                  data-size="icon-xs"
                  phx-click="decrease_quantity"
                  phx-value-id={line.id}
                  aria-label="Decrease quantity"
                  disabled={not is_nil(@checkout_stage)}
                >
                  −
                </button>
                <input
                  class="quantity-input"
                  type="number"
                  inputmode="numeric"
                  min="1"
                  value={line.qty}
                  phx-change="set_quantity"
                  phx-value-id={line.id}
                  aria-label="Item count"
                  disabled={not is_nil(@checkout_stage)}
                /><button
                  class="btn"
                  type="button"
                  data-variant="outline"
                  data-size="icon-xs"
                  phx-click="increase_quantity"
                  phx-value-id={line.id}
                  aria-label="Increase quantity"
                  disabled={not is_nil(@checkout_stage)}
                >
                  +
                </button>
              </div>
              <strong
                class="cart-line-total cart-line-discount-trigger numeric"
                title="Apply a discount to this item"
                role="button"
                tabindex="0"
                phx-click="open_line_discount"
                phx-keydown="open_line_discount"
                phx-value-id={line.id}
              >
                {money(line_gross(line) - line_discount(line))}
              </strong>
            </div>
          </article>
        </div>
        <footer class="order-summary">
          <hr class="separator" role="none" />
          <dl class="totals">
            <div>
              <dt>Items</dt>
              <dd>{items(@socket)}</dd>
            </div>
            <div>
              <dt>Subtotal</dt>
              <dd class="numeric">{money(subtotal(@socket))}</dd>
            </div>
            <div>
              <dt>Tax (18%)</dt>
              <dd class="numeric">{money(tax(@socket))}</dd>
            </div>
            <div>
              <dt>Discount</dt>
              <dd class="numeric discount-value">
                −{money(line_discount_total(@socket) + order_discount_total(@socket))}
              </dd>
            </div>
            <div :if={@delivery > 0}>
              <dt>Delivery</dt>
              <dd class="numeric">{money(@delivery)}</dd>
            </div>
            <div
              class="grand-total order-discount-trigger"
              title="Apply a discount to this sale"
              role="button"
              tabindex="0"
              phx-click="open_order_discount"
              phx-keydown="open_order_discount_key"
              aria-label="Apply order discount. Press Enter."
            >
              <dt>Total</dt>
              <dd class="numeric">{money(total(@socket))}</dd>
            </div>
          </dl>
          <div class="payment-label">
            <span>Payment method</span><span id="payment-choice" class="payment-choice">{payment_choice(@socket)}</span>
          </div>
          <button
            :if={is_nil(@checkout_stage)}
            id="start-checkout"
            class="btn charge-button"
            type="button"
            data-variant="default"
            data-size="lg"
            phx-click="open_checkout"
            disabled={@cart == []}
          >
            Continue
          </button>
        </footer>
      </aside>
      <button
        :if={@mobile_cart_open}
        class="mobile-cart-backdrop is-visible"
        type="button"
        phx-click="close_mobile_cart"
        aria-label="Close sale"
      >
      </button>
      <dialog :if={@dialog == :clear_sale} open class="dialog" data-size="sm">
        <div class="dialog-content">
          <div class="dialog-header">
            <h2 class="dialog-title">Clear this order?</h2>
            <p class="dialog-description">All items and line discounts will be removed.</p>
          </div>
          <div class="dialog-footer">
            <button class="btn" type="button" data-variant="outline" phx-click="close_dialog">
              Cancel
            </button><button
              class="btn"
              type="button"
              data-variant="destructive"
              phx-click="clear_sale"
            >Clear order</button>
          </div>
        </div>
      </dialog>
      <.customer_dialog
        :if={@customer_dialog?}
        status={@customer_form_status}
        saving={@saving_customer?}
      />
      <dialog
        :if={@dialog == :discount}
        id="discount-dialog"
        class="dialog"
        data-size="sm"
        phx-hook="DiscountDialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="discount-title"
      >
        <div class="dialog-content">
          <div class="dialog-header">
            <div class="discount-heading">
              <div>
                <p class="eyebrow">
                  {if @discount_target, do: "Line item discount", else: "Order discount"}
                </p>
                <h2 id="discount-title" class="dialog-title">
                  {if @discount_target, do: "Apply a discount", else: "Apply an order discount"}
                </h2>
                <p class="dialog-description">{discount_subject(assigns)}</p>
              </div>
              <img
                :if={discount_image(assigns)}
                class="discount-product-image"
                src={discount_image(assigns)}
                alt=""
              />
            </div>
          </div>
          <form
            id="discount-form"
            class="form"
            phx-hook="DiscountPreview"
            phx-submit="apply_discount"
            data-discount-base={discount_base(assigns)}
            data-discount-type={@discount_type}
          >
            <input id="discount-type" name="discount_type" type="hidden" value={@discount_type} />
            <div class="discount-switch" role="group" aria-label="Discount type">
              <button
                class="btn"
                type="button"
                data-discount-type="percent"
                data-variant={if @discount_type == "percent", do: "default", else: "secondary"}
                aria-pressed={to_string(@discount_type == "percent")}
              >
                %
              </button><button
                class="btn"
                type="button"
                data-discount-type="amount"
                data-variant={if @discount_type == "amount", do: "default", else: "secondary"}
                aria-pressed={to_string(@discount_type == "amount")}
              >$</button>
            </div>
            <div class="form-field">
              <label id="discount-input-label" class="label" for="discount-input">
                {if @discount_type == "percent", do: "Discount percentage", else: "Discount amount"}
              </label>
              <div class="form-field-inline">
                <input
                  id="discount-input"
                  class="input numeric"
                  style="flex: 1"
                  name="value"
                  type="number"
                  inputmode="decimal"
                  min="0"
                  max={if @discount_type == "percent", do: "100"}
                  step="0.01"
                  value={@discount_input}
                /><button class="btn" type="button" data-variant="outline" data-clear-discount>
                  Clear
                </button>
              </div>
              <p id="discount-help" class="field-description">
                {if @discount_type == "percent",
                  do: "Enter 0 to remove this item discount.",
                  else: "The amount applies to this entire order line."}
              </p>
            </div>
            <dl class="discount-preview">
              <div>
                <dt>Amount</dt>
                <dd class="numeric">{money(discount_base(assigns))}</dd>
              </div>
              <div>
                <dt>Discount</dt>
                <dd class="numeric">−{money(discount_preview(assigns))}</dd>
              </div>
              <div>
                <dt>After discount</dt>
                <dd class="numeric">{money(discount_base(assigns) - discount_preview(assigns))}</dd>
              </div>
            </dl>
            <div class="dialog-footer">
              <button class="btn" type="button" data-variant="outline" phx-click="close_dialog">
                Cancel
              </button><button class="btn" type="submit" data-variant="default">Apply discount</button>
            </div>
          </form>
        </div>
      </dialog>
      <dialog
        :if={@dialog == :customer_purchases}
        id="customer-purchases-dialog"
        class="dialog"
        data-size="xl"
        phx-hook="DiscountDialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="customer-purchases-title"
      >
        <div class="dialog-content">
          <div class="dialog-header">
            <h2 id="customer-purchases-title" class="dialog-title">
              {@selected_customer.name} — recent purchases
            </h2>
            <p class="dialog-description">The 10 most recent purchases, newest first.</p>
          </div>
          <div class="dialog-body">
            <p :if={@customer_purchases == []} class="customers-status" role="status">
              No purchases found.
            </p>
            <div class="table-container">
              <table class="table">
                <caption class="table-caption">
                  Customer purchase history. Expand an item count to view the sold items.
                </caption>
                <thead>
                  <tr class="table-row">
                    <th class="table-head" scope="col">Date</th>
                    <th class="table-head" scope="col">Salesperson</th>
                    <th class="table-head" scope="col">Items</th>
                    <th class="table-head" scope="col">Status</th>
                    <th class="table-head" scope="col" style="text-align:right">Total</th>
                  </tr>
                </thead>
                <tbody id="customer-purchases-body" phx-hook="CustomerPurchases">
                  <%= for purchase <- @customer_purchases do %>
                    <tr class="table-row">
                      <td class="table-cell">{purchase_date(purchase.date_create)}</td>
                      <td class="table-cell">{purchase.salesperson || "—"}</td>
                      <td class="table-cell">
                        <button
                          class="btn customer-purchase-detail-trigger"
                          type="button"
                          data-variant="ghost"
                          data-customer-purchase-details={purchase.id}
                          aria-expanded="false"
                          aria-controls={"customer-purchase-items-#{purchase.id}"}
                        >
                          <span class="customer-purchase-disclosure" aria-hidden="true">▸</span>Items ({length(
                            purchase.items
                          )})
                        </button>
                      </td>
                      <td class="table-cell">{purchase.invoice_status || purchase.status || "—"}</td>
                      <td class="table-cell numeric" style="text-align:right">
                        {money(float(purchase.amount))}
                      </td>
                    </tr>
                    <tr
                      id={"customer-purchase-items-#{purchase.id}"}
                      class="table-row customer-purchase-details-row"
                      hidden
                    >
                      <td class="table-cell" colspan="5">
                        <table class="table customer-purchase-items-table">
                          <caption class="sr-only">
                            Items on {purchase.sequence || "sale #{purchase.id}"}
                          </caption>
                          <thead>
                            <tr class="table-row">
                              <th class="table-head" scope="col">Item</th>
                              <th class="table-head" scope="col">Quantity</th>
                              <th class="table-head" scope="col">Price</th>
                              <th class="table-head" scope="col">Discount</th>
                              <th class="table-head" scope="col">Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr :for={item <- purchase.items} class="table-row">
                              <td class="table-cell">{item.name || "Product ##{item.product_id}"}</td>
                              <td class="table-cell">{item.quantity}</td>
                              <td class="table-cell numeric">{money(float(item.price))}</td>
                              <td class="table-cell numeric">{purchase_discount(item)}</td>
                              <td class="table-cell numeric">{money(float(item.total))}</td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
          <div class="dialog-footer">
            <button class="btn" type="button" data-variant="outline" phx-click="close_dialog">
              Close
            </button>
          </div>
        </div>
      </dialog>
      <.print_dialog :if={@print_prompt} prompt={@print_prompt} />
    </.pos_layout>
    """
  end

  defp load_products(%{assigns: %{loading_products: true}} = socket), do: socket
  defp load_products(%{assigns: %{has_more: false}} = socket), do: socket

  defp load_products(socket) do
    assign(socket, :loading_products, true)

    case Sql.active_products_page(socket.assigns.cursor,
           store_id: socket.assigns.store_id,
           limit: 100
         ) do
      {:ok, page} ->
        socket
        |> assign(
          :products,
          socket.assigns.products ++ Enum.map(page.entries, &normalize_product/1)
        )
        |> assign(:cursor, page.next_cursor)
        |> assign(:has_more, page.has_more?)
        |> assign(:loading_products, false)

      {:error, _} ->
        socket
        |> assign(:loading_products, false)
        |> put_flash(:error, "Products could not be loaded.")
    end
  end

  # InventoryEvents carries only product ids. Fetching just the affected loaded
  # products keeps every terminal current without reloading or disturbing the
  # catalog's cursor, search, or cart state.
  defp refresh_inventory_products(socket, product_ids) do
    changed = MapSet.new(product_ids)

    products =
      Enum.flat_map(socket.assigns.products, fn product ->
        if MapSet.member?(changed, product.id) do
          case Sql.active_product(product.id, socket.assigns.store_id) do
            {:ok, nil} -> []
            {:ok, fresh} -> [normalize_product(fresh)]
            {:error, _} -> [product]
          end
        else
          [product]
        end
      end)

    loaded_ids = MapSet.new(Enum.map(socket.assigns.products, & &1.id))

    new_products =
      changed
      |> MapSet.difference(loaded_ids)
      |> Enum.flat_map(fn product_id ->
        case Sql.active_product(product_id, socket.assigns.store_id) do
          {:ok, fresh} when is_map(fresh) -> [normalize_product(fresh)]
          _ -> []
        end
      end)

    assign(socket, :products, new_products ++ products)
  end

  defp load_customers(socket) do
    case Sql.recent_clients_page(nil, socket.assigns.customer_search, limit: 100) do
      {:ok, page} -> assign(socket, :customers, Enum.map(page.entries, &normalize_customer/1))
      _ -> assign(socket, :customers, [])
    end
  end

  defp restore_pos_draft(socket, %{"store_id" => store_id} = draft) do
    if to_string(store_id) == to_string(socket.assigns.store_id) do
      socket
      |> assign(:cart, restore_cart(Map.get(draft, "cart", []), socket.assigns.store_id))
      |> assign(:selected_customer, restore_customer(Map.get(draft, "selected_customer")))
      |> assign(:order_discount, float(Map.get(draft, "order_discount")))
      |> assign(:order_discount_type, discount_type(Map.get(draft, "order_discount_type")))
      |> assign(:delivery, max(0.0, float(Map.get(draft, "delivery"))))
      |> assign(:delivery_open, truthy?(Map.get(draft, "delivery_open")))
      |> assign(:delivery_custom_input, delivery_amount_input(Map.get(draft, "delivery_custom_input", "")))
      |> assign(:delivery_custom_selected, truthy?(Map.get(draft, "delivery_custom_selected")))
      |> assign(:credit, truthy?(Map.get(draft, "credit")))
      |> assign(:credit_due_date, text(Map.get(draft, "credit_due_date")))
      |> assign(:payments, restore_payments(Map.get(draft, "payments", [])))
      |> assign(:sequence, sequence(Map.get(draft, "sequence")))
      |> assign(:memo, String.slice(text(Map.get(draft, "memo")), 0, 1000))
      |> sync()
    else
      socket
    end
  end

  defp restore_pos_draft(socket, _), do: socket

  defp restore_cart(lines, store_id) when is_list(lines) do
    Enum.flat_map(lines, fn line ->
      with product_id when product_id > 0 <- integer(value(line, :id) || value(line, :product_id)),
           {:ok, product} when is_map(product) <- Sql.active_product(product_id, store_id) do
        product = normalize_product(product)

        [
          %{
            id: product.id,
            name: product.name || "Unnamed product",
            price: float(product.price),
            sub: float(product.sub),
            tax: float(product.tax),
            image_raw: product.image_raw,
            qty: max(1, integer(value(line, :qty))),
            discount: max(0.0, float(value(line, :discount))),
            discount_type: discount_type(value(line, :discount_type))
          }
        ]
      else
        _ -> []
      end
    end)
  end

  defp restore_cart(_, _), do: []

  defp restore_customer(nil), do: nil

  defp restore_customer(customer) when is_map(customer) do
    customer
    |> normalize_customer()
    |> then(fn normalized -> if normalized.id, do: normalized, else: nil end)
  end

  defp restore_customer(_), do: nil

  defp restore_payments(payments) when is_list(payments) do
    Enum.flat_map(payments, fn payment ->
      amount = max(0.0, float(value(payment, :amount)))

      if amount > 0 do
        [
          %{
            id: text(value(payment, :id), "payment-#{System.unique_integer([:positive])}"),
            type: payment_type(value(payment, :type)),
            amount: amount,
            split_source: value(payment, :split_source),
            auto_amount: truthy?(value(payment, :auto_amount))
          }
        ]
      else
        []
      end
    end)
  end

  defp restore_payments(_), do: []

  defp draft_payload(assigns) do
    %{
      store_id: assigns.store_id,
      cart:
        Enum.map(assigns.cart, fn line ->
          %{
            id: line.id,
            qty: line.qty,
            discount: line.discount,
            discount_type: line.discount_type
          }
        end),
      selected_customer: assigns.selected_customer,
      order_discount: assigns.order_discount,
      order_discount_type: assigns.order_discount_type,
      delivery: assigns.delivery,
      delivery_open: assigns.delivery_open,
      delivery_custom_input: assigns.delivery_custom_input,
      delivery_custom_selected: assigns.delivery_custom_selected,
      credit: assigns.credit,
      credit_due_date: assigns.credit_due_date,
      payments: assigns.payments,
      sequence: assigns.sequence,
      memo: assigns.memo
    }
  end

  defp add_product(socket, p) do
    cart =
      case Enum.find_index(socket.assigns.cart, &(&1.id == p.id)) do
        nil ->
          socket.assigns.cart ++
            [
              %{
                id: p.id,
                name: p.name || "Unnamed product",
                price: float(p.price),
                sub: float(p.sub),
                tax: float(p.tax),
                image_raw: p.image_raw,
                qty: 1,
                discount: 0.0,
                discount_type: "amount"
              }
            ]

        index ->
          List.update_at(
            socket.assigns.cart,
            index,
            &Map.update!(&1, :qty, fn qty -> qty + 1 end)
          )
      end

    assign(socket, :cart, cart)
  end

  defp change_quantity(socket, id, delta),
    do:
      Enum.find(socket.assigns.cart, &(to_string(&1.id) == id))
      |> then(fn line ->
        if line, do: set_quantity(socket, id, line.qty + delta), else: socket
      end)

  defp set_quantity(socket, id, qty),
    do:
      if(qty < 1,
        do:
          assign(socket, :cart, Enum.reject(socket.assigns.cart, &(to_string(&1.id) == id)))
          |> sync(),
        else:
          assign(
            socket,
            :cart,
            Enum.map(socket.assigns.cart, fn line ->
              if to_string(line.id) == id, do: %{line | qty: qty}, else: line
            end)
          )
          |> sync()
      )

  defp apply_discount(socket, value) do
    discount_target = socket.assigns.discount_target

    socket =
      if socket.assigns.discount_target do
        assign(
          socket,
          :cart,
          Enum.map(socket.assigns.cart, fn line ->
            if(to_string(line.id) == socket.assigns.discount_target,
              do: %{line | discount: value, discount_type: socket.assigns.discount_type},
              else: line
            )
          end)
        )
      else
        socket
        |> assign(:order_discount, value)
        |> assign(:order_discount_type, socket.assigns.discount_type)
        |> assign(
          :cart,
          Enum.map(socket.assigns.cart, &%{&1 | discount: 0.0, discount_type: "amount"})
        )
      end

    socket = socket |> assign(:dialog, nil) |> sync()

    if discount_target,
      do: push_event(socket, "pos:cart-bump", %{id: discount_target}),
      else: socket
  end

  defp change_custom_delivery_amount(socket, amount) do
    amount = delivery_amount_input(amount)

    socket =
      socket
      |> assign(:delivery_open, true)
      |> assign(:delivery_custom_input, amount)
      |> assign(:delivery_custom_selected, false)

    socket
  end

  defp delivery_amount_input(value) do
    value = value |> to_string() |> String.trim()

    case Float.parse(value) do
      {amount, ""} when amount >= 0 -> value
      _ -> ""
    end
  end

  defp update_payment(socket, id, "type", value),
    do:
      assign(
        socket,
        :payments,
        Enum.map(socket.assigns.payments, fn p ->
          if p.id == id, do: %{p | type: value}, else: p
        end)
      )

  defp update_payment(socket, id, "amount", value) do
    entered = max(0.0, float(value))
    payment = Enum.find(socket.assigns.payments, &(&1.id == id))

    payments =
      if payment do
        previous = payment.amount
        change = Float.round(entered - previous, 2)
        total_before_change = paid(socket) - entered + previous

        # Once an amount is typed by the cashier it is no longer the
        # automatically-filled balance line. Delivery changes must preserve
        # this explicit split and only refresh the remaining automatic line.
        payments =
          Enum.map(socket.assigns.payments, fn p ->
            if p.id == id,
              do: p |> Map.put(:amount, entered) |> Map.put(:auto_amount, false),
              else: p
          end)

        case Map.get(payment, :split_source) &&
               Enum.find(payments, &(&1.id == payment.split_source)) do
          nil ->
            payments

          source ->
            change_absorbed =
              if change < 0,
                do: min(-change, max(0.0, total_before_change - total(socket))),
                else: 0.0

            transferred =
              if change > 0, do: min(change, source.amount), else: change + change_absorbed

            Enum.map(payments, fn p ->
              if p.id == source.id,
                do: %{p | amount: Float.round(max(0.0, p.amount - transferred), 2)},
                else: p
            end)
        end
      else
        socket.assigns.payments
      end

    assign(socket, :payments, payments)
  end

  defp update_payment(socket, _, _, _), do: socket

  # Tauri keeps an untouched initial payment populated with the balance due.
  # Delivery changes the sale total, so refresh that one automatic line while
  # retaining every amount the cashier has explicitly entered for a split.
  defp set_delivery_total(socket, delivery) do
    socket = assign(socket, :delivery, max(0.0, delivery))

    # A single payment is the balance line produced by Tauri's “Add payment”.
    # It remains the balance line until the cashier creates a split. Do not
    # depend on an input event marker here: LiveView can emit an input event
    # while restoring the number control, even when the cashier did not edit it.
    automatic_payment =
      case socket.assigns.payments do
        [payment] -> payment
        payments -> Enum.find(payments, fn payment -> Map.get(payment, :auto_amount, false) end)
      end

    payments =
      case automatic_payment do
        nil ->
          socket.assigns.payments

        payment ->
          paid_by_other_lines =
            socket.assigns.payments
            |> Enum.reject(&(&1.id == payment.id))
            |> Enum.sum_by(& &1.amount)

          amount = Float.round(max(0.0, total(socket) - paid_by_other_lines), 2)

          Enum.map(socket.assigns.payments, fn line ->
            if line.id == payment.id, do: %{line | amount: amount}, else: line
          end)
      end

    assign(socket, :payments, payments)
  end

  defp line_gross(line), do: line.price * line.qty

  defp line_discount(line),
    do:
      if(line.discount_type == "percent",
        do: line_gross(line) * min(line.discount, 100) / 100,
        else: min(line.discount, line_gross(line))
      )

  defp line_factor(line),
    do:
      if(line_gross(line) == 0,
        do: 1,
        else: (line_gross(line) - line_discount(line)) / line_gross(line)
      )

  defp subtotal(state),
    do:
      Enum.sum(
        Enum.map(state(state).cart, fn line ->
          line.sub * line.qty * line_factor(line) * order_factor(state)
        end)
      )

  defp line_discount_total(state), do: Enum.sum(Enum.map(state(state).cart, &line_discount/1))
  defp gross_subtotal(state), do: Enum.sum(Enum.map(state(state).cart, &line_gross/1))
  defp before_order_discount(state), do: gross_subtotal(state) - line_discount_total(state)

  defp order_discount_total(state),
    do:
      if(state(state).order_discount_type == "percent",
        do: before_order_discount(state) * min(state(state).order_discount, 100) / 100,
        else: min(state(state).order_discount, before_order_discount(state))
      )

  defp discount_type_for_sale(state),
    do: if(state(state).order_discount_type == "percent", do: "percentage", else: "money")

  defp merchandise_total(state), do: before_order_discount(state) - order_discount_total(state)
  defp total(state), do: merchandise_total(state) + state(state).delivery

  defp order_factor(state),
    do:
      if(before_order_discount(state) == 0,
        do: 1,
        else: merchandise_total(state) / before_order_discount(state)
      )

  defp tax(state),
    do:
      Enum.sum(
        Enum.map(state(state).cart, fn line ->
          line.tax * line.qty * line_factor(line) * order_factor(state)
        end)
      )

  defp items(state), do: Enum.sum(Enum.map(state(state).cart, & &1.qty))
  defp paid(state), do: Enum.sum(Enum.map(state(state).payments, & &1.amount))
  defp remaining(socket), do: max(0.0, total(socket) - paid(socket))

  defp payment_choice(state) do
    if state(state).credit do
      "Credit"
    else
      state(state).payments
      |> Enum.map(fn payment -> if payment.type == "CC", do: "Credit Card", else: "Cash" end)
      |> Enum.uniq()
      |> Enum.join(" + ")
      |> case do
        "" -> "—"
        value -> value
      end
    end
  end

  defp payment_amount_input(value), do: :erlang.float_to_binary(float(value), decimals: 2)

  defp assign_credit_due_date(socket, %{"credit_due_date" => value}),
    do: assign(socket, :credit_due_date, value)

  defp assign_credit_due_date(socket, _params), do: socket

  defp payment_complete?(state) do
    state = state(state)

    if state.credit do
      future_due_date?(state.credit_due_date)
    else
      paid(state) >= total(state)
    end
  end

  defp future_due_date_min, do: Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

  defp future_due_date?(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, due_date} -> Date.compare(due_date, Date.utc_today()) == :gt
      _ -> false
    end
  end

  defp future_due_date?(_), do: false

  defp float(value) when is_number(value), do: value * 1.0
  defp float(%Decimal{} = value), do: Decimal.to_float(value)

  defp float(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _remainder} -> number
      :error -> 0.0
    end
  end

  defp float(_), do: 0.0
  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp integer(_), do: 0

  defp truthy?(value), do: value in [true, "true", 1, "1"]
  defp text(value, fallback \\ "")
  defp text(value, _fallback) when is_binary(value), do: value
  defp text(nil, fallback), do: fallback
  defp text(value, _fallback), do: to_string(value)

  defp discount_type("percent"), do: "percent"
  defp discount_type(_), do: "amount"

  defp payment_type("CC"), do: "CC"
  defp payment_type(_), do: "CASH"

  defp sequence(sequence) when sequence in ["CF", "VF", "DV"], do: sequence
  defp sequence(_), do: "CF"

  defp discount_input_value(value) when value == 0 or value == 0.0, do: ""
  defp discount_input_value(value), do: :erlang.float_to_binary(value, decimals: 2)

  defp money(value) do
    value = Float.round(value * 1.0, 2)
    [whole, cents] = :erlang.float_to_binary(value, decimals: 2) |> String.split(".")

    "$#{whole |> String.reverse() |> String.graphemes() |> Enum.chunk_every(3) |> Enum.map_join(",", &Enum.join(&1)) |> String.reverse()}.#{cents}"
  end

  defp purchase_date(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M")
  defp purchase_date(_), do: "—"

  defp purchase_discount(item) do
    discount = float(item.discount)

    cond do
      discount == 0 ->
        "—"

      item.discount_type == "percentage" and not is_nil(item.discount_input) ->
        "#{float(item.discount_input)}%"

      true ->
        money(discount)
    end
  end

  defp sequence_description("CF"), do: "Consumer final"
  defp sequence_description("DV"), do: "Direct sale"
  defp sequence_description("VF"), do: "Fiscal voucher"
  defp sequence_description(_), do: ""

  defp visible_products(assigns) do
    query = String.downcase(String.trim(assigns.product_search))

    if query == "",
      do: assigns.products,
      else:
        Enum.filter(assigns.products, fn product ->
          String.contains?(String.downcase("#{product.name || ""} #{product.code || ""}"), query)
        end)
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

  defp active_store_name(assigns),
    do:
      Enum.find_value(assigns.stores, "", fn store ->
        if store.id == assigns.store_id, do: store.name
      end)

  defp discount_line(assigns),
    do: Enum.find(assigns.cart, &(to_string(&1.id) == assigns.discount_target))

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

    if assigns.discount_type == "percent",
      do: base * min(entered, 100) / 100,
      else: min(entered, base)
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
      document_id: value(customer, :document_id),
      email: value(customer, :email),
      wholesaler: value(customer, :wholesaler),
      is_wholesaler: value(customer, :is_wholesaler)
    }
  end

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp print_request_id, do: "print-#{System.unique_integer([:positive])}"

  defp receipt_payload(sale, store) do
    %{
      id: value(sale, :id),
      sequence: value(sale, :sequence),
      client_name: value(value(sale, :client) || %{}, :name),
      client_document_id: value(value(sale, :client) || %{}, :document_id),
      login: value(sale, :login),
      sale_type: value(sale, :sale_type),
      amount: value(sale, :amount),
      sub: value(sale, :sub),
      tax_amount: value(sale, :tax_amount),
      discount: value(sale, :discount),
      delivery_charge: value(sale, :delivery_charge),
      additional_info: value(sale, :additional_info),
      date_create: value(sale, :date_create),
      due_date: value(sale, :due_date),
      sequence_type: value(sale, :sequence_type),
      status: value(sale, :status),
      total_paid: value(sale, :total_paid),
      change_amount: value(sale, :change_amount),
      due_balance: value(sale, :due_balance),
      invoice_status: value(sale, :invoice_status),
      store: store,
      lines:
        Enum.map(value(sale, :sale_lines) || value(sale, :lines) || [], fn line ->
          %{
            product_id: value(line, :product_id),
            product: %{
              name: value(value(line, :product) || %{}, :name),
              code: value(value(line, :product) || %{}, :code)
            },
            quantity: value(line, :quantity),
            amount: value(line, :amount),
            tax_amount: value(line, :tax_amount),
            discount: value(line, :discount),
            discount_type: value(line, :discount_type),
            discount_input: value(line, :discount_input),
            total_amount: value(line, :total_amount)
          }
        end),
      payments:
        Enum.map(value(sale, :sale_paids) || value(sale, :payments) || [], fn payment ->
          %{
            id: value(payment, :id),
            type: value(payment, :type),
            amount: value(payment, :amount),
            login: value(payment, :login),
            date_create: value(payment, :date_create)
          }
        end)
    }
  end

  defp current_store(socket),
    do: Enum.find(socket.assigns.stores, &(&1.id == socket.assigns.store_id))

  defp print_prompt(:receipt, receipt) do
    %{
      title: "Sale completed",
      description: "Would you like to print the receipt?",
      button: "Print receipt",
      event: "printer:print-receipt",
      payload: %{request_id: print_request_id(), receipt: receipt}
    }
  end

  defp update_print_prompt(%{assigns: %{print_prompt: nil}} = socket, _status, _printing),
    do: socket

  defp update_print_prompt(socket, status, printing),
    do: update(socket, :print_prompt, &Map.merge(&1, %{status: status, printing: printing}))

  attr :prompt, :map, required: true

  defp print_dialog(assigns) do
    ~H"""
    <dialog
      id="receipt-dialog"
      class="dialog"
      data-size="sm"
      open
      role="dialog"
      aria-modal="true"
      aria-labelledby="receipt-dialog-title"
    >
      <div class="dialog-content">
        <div class="dialog-header">
          <h2 id="receipt-dialog-title" class="dialog-title">{@prompt.title}</h2>
          <p id="receipt-print-description" class="dialog-description">{@prompt.description}</p>
        </div>
        <p id="receipt-print-status" class="print-status" role="status">{@prompt[:status] || ""}</p>
        <div class="dialog-footer">
          <button
            id="skip-print"
            class="btn"
            type="button"
            data-variant="outline"
            phx-click="skip_print"
            disabled={@prompt[:printing] == true}
          >
            No, return to POS
          </button><button
            id="print-receipt"
            class="btn"
            type="button"
            data-variant="default"
            phx-click="confirm_print"
            disabled={@prompt[:printing] == true}
          >{@prompt.button}</button>
        </div>
      </div>
    </dialog>
    """
  end

  defp wholesaler_value(value) when value in [true, 1, "1", "true", "on"], do: 1
  defp wholesaler_value(_), do: 0

  defp selected_store(stores, selected_id) do
    case Integer.parse(to_string(selected_id || "")) do
      {id, ""} -> Enum.find(stores, List.first(stores), &(&1.id == id))
      _ -> List.first(stores)
    end
  end

  defp state(%{assigns: assigns}), do: assigns
  defp state(assigns), do: assigns
  defp sync(socket) do
    socket
    |> assign(:pos_state, Map.drop(socket.assigns, [:pos_state]))
    |> push_event("pos:draft-changed", %{draft: draft_payload(socket.assigns)})
  end
end
