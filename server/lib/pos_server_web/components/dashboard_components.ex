defmodule PosServerWeb.DashboardComponents do
  use PosServerWeb, :html

  attr :active, :any, required: true
  attr :tenant, :string, default: nil

  def dashboard_sidebar(assigns) do
    assigns = assign(assigns, :addons, PosServer.Addons.enabled_for(assigns.tenant))

    ~H"""
    <aside class="dashboard-sidebar" aria-label="Primary navigation">
      <div class="dashboard-sidebar-brand">
        <a class="brand" href={~p"/dash"}><span class="brand-mark" aria-hidden="true">T</span><span class="dashboard-sidebar-label">tigoo</span></a>
        <button class="btn" data-variant="ghost" data-size="icon-sm" type="button" data-dashboard-sidebar-toggle aria-label="Collapse navigation" aria-expanded="true">
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>
        </button>
      </div>
      <nav class="dashboard-nav" aria-label="Dashboard navigation">
        <a class={[@active == :dash && "is-active"]} href={~p"/dash"} aria-current={if @active == :dash, do: "page"}>
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg><span class="dashboard-sidebar-label">Dashboard</span>
        </a>
        <a class={[@active == :addons && "is-active"]} href={~p"/addons/install"} aria-current={if @active == :addons, do: "page"}>
          <span aria-hidden="true">＋</span><span class="dashboard-sidebar-label">Install Addon</span>
        </a>
        <a :for={addon <- @addons} class={[@active == addon.identifier && "is-active"]} href={addon.route} aria-current={if @active == addon.identifier, do: "page"}>
          <span aria-hidden="true"><%= addon.icon %></span><span class="dashboard-sidebar-label"><%= addon.name %></span>
        </a>
      </nav>
      <div class="dashboard-sidebar-footer"><span class="dashboard-sidebar-label">Workspace management</span></div>
    </aside>
    """
  end
end
