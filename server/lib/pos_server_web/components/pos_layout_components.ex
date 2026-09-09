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
      {render_slot(@before_layout)}
      <nav class="sidebar-rail" aria-label="Primary navigation">
        <a
          class="sidebar-link"
          href={pos_href(@active_page)}
          aria-current={current_page(@active_page, :pos)}
          aria-label="POS"
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
          class="sidebar-link"
          href={~p"/pos/customers"}
          aria-current={current_page(@active_page, :customers)}
          aria-label="Customers"
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
          class="sidebar-link"
          href={~p"/pos/invoices"}
          aria-current={current_page(@active_page, :invoices)}
          aria-label="Invoice report"
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
          class="sidebar-link"
          href={~p"/pos/inventory"}
          aria-current={current_page(@active_page, :inventory)}
          aria-label="Inventory"
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
          class="sidebar-link"
          href={~p"/pos/orders"}
          aria-current={current_page(@active_page, :orders)}
          aria-label="Purchase orders"
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
          :if={Scope.allowed?(@scope, "company.settings")}
          id="company-settings-nav"
          class="sidebar-link"
          href={~p"/pos/company-settings"}
          aria-current={current_page(@active_page, :company_settings)}
          aria-label="Company settings"
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
        <details class="sidebar-menu sidebar-store-selector">
          <summary class="sidebar-menu-trigger" aria-label="Choose active store">⌂</summary>
          <div class="user-menu-content sidebar-menu-content" role="group" aria-label="Active store">
            <button
              :for={store <- @stores}
              class="sidebar-menu-action"
              type="button"
              phx-click="change_store"
              phx-value-store_id={store.id}
              aria-pressed={to_string(store.id == @store_id)}
            >
              {store.name}
            </button>
          </div>
        </details>
        <details
          id={"#{@id}-theme-selector"}
          class="sidebar-menu sidebar-theme-selector"
          phx-hook="PosTheme"
        >
          <summary class="sidebar-menu-trigger" aria-label="Choose theme">◐</summary>
          <div class="user-menu-content sidebar-menu-content">
            <button
              class="sidebar-menu-action"
              type="button"
              phx-click={JS.dispatch("pos:set-theme", detail: %{theme: "default-light"})}
            >
              Default Light
            </button>
          </div>
        </details>
      </nav>
      <div class="status-strip" aria-label="System status">
        <span class="session-store-status" aria-live="polite">{@scope.login}</span>
        <details class="language-switcher">
          <summary aria-label="Change display language">
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
          <div class="language-menu" role="group">
            <button type="button">English</button><button type="button">Español</button><button type="button">Português</button>
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
          class="network-status"
          role="img"
          aria-label="Network status available"
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
