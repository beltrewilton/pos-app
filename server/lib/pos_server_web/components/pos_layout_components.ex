defmodule PosServerWeb.PosLayoutComponents do
  @moduledoc false
  use PosServerWeb, :html

  alias PosServer.Accounts.Scope

  attr(:id, :string, required: true)
  attr(:class, :string, default: "pos-shell")
  attr(:active_page, :atom, required: true)
  attr(:scope, :map, required: true)
  attr(:stores, :list, required: true)
  attr(:store_id, :any, required: true)
  attr(:rest, :global)

  slot(:before_layout)
  slot(:inner_block, required: true)

  def pos_layout(assigns) do
    ~H"""
    <main id={@id} class={@class} {@rest}>
      <span
        id={"#{@id}-store-preference"}
        phx-hook="StorePreference"
        data-store-id={@store_id}
        hidden
      >
      </span>
      {render_slot(@before_layout)}
      <nav
        class="sidebar-rail"
        aria-label="Primary navigation"
        data-i18n-aria-label="layout.nav.primary"
      >
        <a
          :if={nav_allowed?(@scope, :dashboard)}
          class="sidebar-link"
          href={~p"/pos/dashboard"}
          aria-current={current_page(@active_page, :dashboard)}
          aria-label="Dashboard"
          data-i18n-aria-label="dashboard.dashboard"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <rect x="3" y="3" width="7" height="9" rx="1" /><rect
              x="14"
              y="3"
              width="7"
              height="5"
              rx="1"
            /><rect x="14" y="12" width="7" height="9" rx="1" /><rect
              x="3"
              y="16"
              width="7"
              height="5"
              rx="1"
            />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :pos)}
          class="sidebar-link"
          href={pos_href(@active_page)}
          aria-current={current_page(@active_page, :pos)}
          aria-label="POS"
          data-i18n-aria-label="layout.nav.pos"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M3 3h18v18H3z" /><path d="M7 7h10v10H7z" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :invoices)}
          class="sidebar-link"
          href={~p"/pos/invoices"}
          aria-current={current_page(@active_page, :invoices)}
          aria-label="Invoice report"
          data-i18n-aria-label="layout.nav.invoices"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M4 2v20h16" /><path d="M8 6h8M8 10h8M8 14h5" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :reconciliation)}
          class="sidebar-link"
          href={~p"/pos/reconciliation"}
          aria-current={current_page(@active_page, :reconciliation)}
          aria-label="Cash reconciliation"
          data-i18n-aria-label="layout.nav.reconciliation"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <rect x="3" y="6" width="18" height="13" rx="2" />
            <path d="M16 6V4H8v2" />
            <path d="M7 11h.01M11 11h6M7 15h.01M11 15h6" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :customers)}
          class="sidebar-link"
          href={~p"/pos/customers"}
          aria-current={current_page(@active_page, :customers)}
          aria-label="Customers"
          data-i18n-aria-label="layout.nav.customers"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :inventory)}
          class="sidebar-link"
          href={~p"/pos/inventory"}
          aria-current={current_page(@active_page, :inventory)}
          aria-label="Inventory"
          data-i18n-aria-label="layout.nav.inventory"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="m12 3 9 5-9 5-9-5 9-5Z" /><path d="m3 12 9 5 9-5M3 16l9 5 9-5" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :orders)}
          class="sidebar-link"
          href={~p"/pos/orders"}
          aria-current={current_page(@active_page, :orders)}
          aria-label="Purchase orders"
          data-i18n-aria-label="layout.nav.orders"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M6 2h9l3 3v17H6z" /><path d="M9 10h6M9 14h6" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :installed_addons)}
          class="sidebar-link"
          href={~p"/pos/addons"}
          aria-current={current_page(@active_page, :installed_addons)}
          aria-label="Installed Add-ons"
          data-i18n-aria-label="addons.installedAddons"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M4 4h6v6H4z" /><path d="M14 4h6v6h-6z" /><path d="M4 14h6v6H4z" /><path d="M14 14h6v6h-6z" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :company_settings)}
          id="company-settings-nav"
          class="sidebar-link"
          href={~p"/pos/company-settings"}
          aria-current={current_page(@active_page, :company_settings)}
          aria-label="Company settings"
          data-i18n-aria-label="layout.nav.companySettings"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="m3 9 2-5h14l2 5" /><path d="M3 9h18v11H3z" /><path d="M7 20v-6h4v6" /><path d="M3 9c0 2 2 3 4 3s4-1 4-3c0 2 2 3 4 3s4-1 4-3" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :users)}
          id="users-nav"
          class="sidebar-link"
          href={~p"/pos/users"}
          aria-current={current_page(@active_page, :users)}
          aria-label="Users"
          data-i18n-aria-label="layout.nav.users"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" /><path d="M19 8v4M17 10h4" />
          </svg>
        </a>
        <a
          :if={nav_allowed?(@scope, :addons)}
          class="sidebar-link"
          href={~p"/pos/addons/install"}
          aria-current={current_page(@active_page, :addons)}
          aria-label="Install Addons"
          data-i18n-aria-label="dashboard.installAddon"
        >
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M12 5v14" /><path d="M5 12h14" />
          </svg>
        </a>
        <details
          id={"#{@id}-theme-selector"}
          class="sidebar-menu sidebar-theme-selector"
        >
          <summary
            class="sidebar-menu-trigger"
            aria-label="Choose theme"
            data-i18n-aria-label="layout.theme.choose"
          >
            <svg
              class="sidebar-theme-icon"
              aria-hidden="true"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <circle cx="13.5" cy="6.5" r=".5" fill="currentColor" /><circle
                cx="17.5"
                cy="10.5"
                r=".5"
                fill="currentColor"
              /><circle cx="8.5" cy="7.5" r=".5" fill="currentColor" /><circle
                cx="6.5"
                cy="12.5"
                r=".5"
                fill="currentColor"
              /><path d="M12 3a9 9 0 1 0 0 18 1.5 1.5 0 0 0 1.5-1.5c0-.4-.16-.78-.44-1.06a1.5 1.5 0 0 1 1.06-2.56H16a5 5 0 0 0 0-10Z" />
            </svg>
          </summary>
          <div
            class="user-menu-content sidebar-menu-content"
            role="group"
            aria-label="Theme"
            data-i18n-aria-label="layout.theme.label"
          >
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="default-light"
              data-i18n="layout.theme.defaultLight"
            >
              Default Light
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="nature-light"
              data-i18n="layout.theme.natureLight"
            >
              Nature Light
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="nature-dark"
              data-i18n="layout.theme.natureDark"
            >
              Nature Dark
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="caffeine-light"
              data-i18n="layout.theme.caffeineLight"
            >
              Caffeine Light
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="caffeine-dark"
              data-i18n="layout.theme.caffeineDark"
            >
              Caffeine Dark
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="bold-tech-light"
              data-i18n="layout.theme.boldTechLight"
            >
              Bold Tech Light
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="bold-tech-dark"
              data-i18n="layout.theme.boldTechDark"
            >
              Bold Tech Dark
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="doom-64-light"
              data-i18n="layout.theme.doom64Light"
            >
              Doom 64 Light
            </button>
            <button
              class="sidebar-menu-action"
              type="button"
              data-theme="doom-64-dark"
              data-i18n="layout.theme.doom64Dark"
            >
              Doom 64 Dark
            </button>
          </div>
        </details>
        <details id={"#{@id}-store-selector"} class="sidebar-menu sidebar-store-selector">
          <summary
            class="sidebar-menu-trigger"
            aria-label="Choose active store"
            data-i18n-aria-label="layout.store.choose"
          >
            <svg
              class="sidebar-store-icon"
              aria-hidden="true"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="m3 9 2-5h14l2 5" /><path d="M3 9h18v11H3z" /><path d="M7 20v-6h4v6" /><path d="M3 9c0 2 2 3 4 3s4-1 4-3c0 2 2 3 4 3s4-1 4-3" />
            </svg>
          </summary>
          <div
            class="user-menu-content sidebar-menu-content"
            role="group"
            aria-label="Active store"
            data-i18n-aria-label="layout.store.active"
          >
            <button
              :for={store <- @stores}
              class="sidebar-menu-action"
              type="button"
              phx-click="change_store"
              phx-value-store_id={store.id}
              aria-current={selected_store?(store.id, @store_id)}
            >
              <span>{store.name}</span>
              <svg
                :if={selected_store?(store.id, @store_id)}
                class="sidebar-menu-check"
                aria-hidden="true"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20 6 9 17l-5-5" />
              </svg>
            </button>
          </div>
        </details>
        <details class="user-menu sidebar-user-menu">
          <summary class="avatar avatar-trigger" aria-label={"Open menu for #{user_name(@scope)}"}>
            <img :if={avatar_image?(@scope)} class="avatar-image" src={@scope.pic} alt="" />
            <span :if={!avatar_image?(@scope)} class="avatar-fallback">{user_initials(@scope)}</span>
          </summary>
          <div
            class="user-menu-content"
            role="group"
            aria-label="User menu"
            data-i18n-aria-label="layout.user.menu"
          >
            <div class="user-menu-identity">
              <span class="avatar avatar-sm" aria-hidden="true">
                <img :if={avatar_image?(@scope)} class="avatar-image" src={@scope.pic} alt="" />
                <span :if={!avatar_image?(@scope)} class="avatar-fallback">
                  {user_initials(@scope)}
                </span>
              </span>
              <span><strong>{user_name(@scope)}</strong><small>{@scope.login}</small></span>
            </div>
            <hr class="separator" />
            <.form for={%{}} action={~p"/pos/logout"} method="delete">
              <button class="user-menu-action" type="submit">
                <svg
                  aria-hidden="true"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M10 17l5-5-5-5" /><path d="M15 12H3" /><path d="M21 19V5a2 2 0 0 0-2-2h-6" />
                </svg>
                <span data-i18n="layout.user.logout">Logout</span>
              </button>
            </.form>
          </div>
        </details>
      </nav>
      <div class="status-strip" aria-label="System status" data-i18n-aria-label="layout.status.system">
        <span class="session-store-status" aria-live="polite">{@scope.login}</span>
        <details class="language-switcher">
          <summary aria-label="Change display language" data-i18n-aria-label="layout.status.language">
            <svg
              aria-hidden="true"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c2.5 2.5 3.7 5.5 3.7 9S14.5 18.5 12 21c-2.5-2.5-3.7-5.5-3.7-9S9.5 5.5 12 3Z" />
            </svg>
          </summary>
          <div
            class="language-menu"
            role="group"
            aria-label="Change display language"
            data-i18n-aria-label="layout.status.language"
          >
            <button type="button" data-language="en">English</button><button
              type="button"
              data-language="es"
            >Español</button><button type="button" data-language="pt">Português</button>
          </div>
        </details>
        <button
          id={"#{@id}-printer-status"}
          class="printer-status"
          style="appearance: none; display: inline-grid; place-items: center; width: 16px; height: 16px; padding: 0; border: 0; background: transparent; line-height: 0; vertical-align: middle;"
          type="button"
          data-printer-status
          data-status="disconnected"
          phx-update="ignore"
          phx-hook="PrinterStatus"
          aria-label="Printer disconnected"
          title="Printer disconnected"
          data-i18n-aria-label="layout.status.printerDisconnected"
          data-i18n-title="layout.status.printerDisconnected"
        >
          <svg
            role="img"
            width="15"
            height="15"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M6 9V3h12v6" /><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" /><path d="M6 14h12v7H6z" />
          </svg>
        </button>
        <svg
          id={"#{@id}-network-status"}
          class="network-status"
          role="img"
          aria-label="Network connected"
          data-i18n-aria-label="layout.status.networkConnected"
          data-network-status
          data-status="connected"
          phx-hook="NetworkStatus"
          phx-update="ignore"
          title="Network connected"
          data-i18n-title="layout.status.networkConnected"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M12 20h.01" /><path d="M2 8.82a15 15 0 0 1 20 0" /><path d="M5 12.859a10 10 0 0 1 14 0" /><path d="M8.5 16.429a5 5 0 0 1 7 0" />
        </svg>
      </div>
      {render_slot(@inner_block)}
    </main>
    """
  end

  defp current_page(page, page), do: "page"
  defp current_page(_, _), do: nil
  defp pos_href(:pos), do: "#"
  defp pos_href(_), do: ~p"/pos"
  defp nav_allowed?(scope, page), do: Scope.allowed?(scope, nav_permission(page))

  defp nav_permission(:dashboard), do: "dashboard.view"
  defp nav_permission(:pos), do: "sales.pos"
  defp nav_permission(:reconciliation), do: "pos.reconciliation"
  defp nav_permission(:customers), do: "pos.customer"
  defp nav_permission(:invoices), do: "sales.view"
  defp nav_permission(:inventory), do: "inventory.view"
  defp nav_permission(:orders), do: "pos.orders"
  defp nav_permission(:installed_addons), do: "pos.addons"
  defp nav_permission(:company_settings), do: "company.settings"
  defp nav_permission(:users), do: "user.view"
  defp nav_permission(:addons), do: "pos.addons.install"

  defp selected_store?(store_id, selected_id), do: to_string(store_id) == to_string(selected_id)

  defp avatar_image?(%{pic: pic}), do: is_binary(pic) and String.trim(pic) != ""
  defp avatar_image?(_), do: false

  defp user_name(%{user: %{name: name}}) when is_binary(name) and name != "", do: name
  defp user_name(%{login: login}) when is_binary(login) and login != "", do: login
  defp user_name(_), do: "User"

  defp user_initials(scope) do
    scope
    |> user_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
    |> case do
      "" -> "U"
      initials -> initials
    end
  end

  attr(:class, :string, default: "")
  attr(:width, :string, default: "100%")

  def skeleton_block(assigns) do
    ~H"""
    <span class={["skeleton", @class]} style={"width:#{@width}"} aria-hidden="true"></span>
    """
  end

  attr(:count, :integer, default: 8)

  def product_skeleton_cards(assigns) do
    ~H"""
    <article :for={_ <- 1..@count} class="card product product-skeleton-card">
      <div class="skeleton product-skeleton-image" aria-hidden="true"></div>
      <div class="card-content product-content">
        <.skeleton_block class="skeleton-line" width="72%" />
        <.skeleton_block class="skeleton-line" width="42%" />
        <.skeleton_block class="skeleton-line" width="58%" />
      </div>
    </article>
    """
  end

  attr(:rows, :integer, default: 6)
  attr(:columns, :integer, default: 8)
  attr(:widths, :list, default: ["72%", "64%", "56%", "58%", "46%", "52%", "60%", "50%"])

  def table_skeleton_rows(assigns) do
    ~H"""
    <tr :for={_ <- 1..@rows} class="table-row skeleton-table-row">
      <td :for={index <- 0..(@columns - 1)} class="table-cell">
        <.skeleton_block class="skeleton-line" width={Enum.at(@widths, index, "100%")} />
      </td>
    </tr>
    """
  end

  attr(:widths, :list, default: ["38%", "72%", "100%", "88%", "64%"])

  def invoice_details_skeleton(assigns) do
    ~H"""
    <div
      class="card-content invoice-details-skeleton"
      role="status"
      aria-label="Loading invoice details"
    >
      <.skeleton_block :for={width <- @widths} class="skeleton-line" width={width} />
    </div>
    """
  end

  def screen_loading_skeleton(assigns) do
    ~H"""
    <div class="screen-loading-skeleton" role="status" aria-label="Loading screen content">
      <div class="screen-loading-header">
        <.skeleton_block class="skeleton-title" width="12rem" />
        <.skeleton_block class="skeleton-control" width="min(42%, 28rem)" />
        <.skeleton_block class="skeleton-control" width="9rem" />
      </div>
      <div class="screen-loading-cards">
        <div :for={span <- [2, 1, 1]} class="screen-loading-card" style={"grid-column:span #{span}"}>
          <.skeleton_block class="skeleton-line" width="44%" />
          <.skeleton_block class="skeleton-line skeleton-value" width="62%" />
          <.skeleton_block class="skeleton-line" width="76%" />
        </div>
      </div>
      <div class="screen-loading-table">
        <div :for={_ <- 1..7} class="screen-loading-table-row">
          <.skeleton_block
            :for={width <- ["72%", "56%", "64%", "52%", "58%", "48%", "50%", "60%", "56%", "52%"]}
            class="skeleton-line"
            width={width}
          />
        </div>
      </div>
    </div>
    """
  end
end
