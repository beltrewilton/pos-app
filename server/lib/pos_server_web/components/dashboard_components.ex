defmodule PosServerWeb.DashboardComponents do
  use PosServerWeb, :html

  attr :active, :atom, required: true

  def dashboard_sidebar(assigns) do
    ~H"""
    <aside class="dashboard-sidebar" aria-label="Primary navigation">
      <div class="dashboard-sidebar-brand">
        <a class="brand" href={~p"/dash"}><span class="brand-mark" aria-hidden="true">R</span><span class="dashboard-sidebar-label">retaily</span></a>
        <button class="btn" data-variant="ghost" data-size="icon-sm" type="button" data-dashboard-sidebar-toggle aria-label="Collapse navigation" aria-expanded="true">
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>
        </button>
      </div>
      <nav class="dashboard-nav" aria-label="Dashboard navigation">
        <a class={[@active == :dash && "is-active"]} href={~p"/dash"} aria-current={if @active == :dash, do: "page"}>
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg><span class="dashboard-sidebar-label">Dashboard</span>
        </a>
        <a class={[@active == :admin && "is-active"]} href={~p"/admin"} aria-current={if @active == :admin, do: "page"}>
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg><span class="dashboard-sidebar-label">Administration</span>
        </a>
      </nav>
      <div class="dashboard-sidebar-footer"><span class="dashboard-sidebar-label">Workspace management</span></div>
    </aside>
    """
  end
end
