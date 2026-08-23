defmodule PosServerWeb.Router do
  use PosServerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PosServerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_desktop_cors_headers
  end

  pipeline :tenant_api do
    plug :accepts, ["json"]
    plug :put_desktop_cors_headers
    plug PosServerWeb.Plugs.FetchCurrentScope
    plug PosServerWeb.Plugs.PutTenantFromScope
    plug PosServerWeb.Plugs.RequireTenant
  end

  scope "/", PosServerWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/users", UserLive, :index
    live "/users/new", UserLive, :new
  end

  scope "/api", PosServerWeb do
    pipe_through :api

    get "/health", HealthController, :show
    options "/*path", HealthController, :show
  end

  scope "/api", PosServerWeb do
    pipe_through :tenant_api

    get "/products", ProductController, :index
    get "/inventory", InventoryController, :index
    post "/inventory/adjustments", InventoryController, :adjust
    post "/product-orders", ProductOrderController, :create
    get "/product-orders", ProductOrderController, :index
    post "/product-orders/:id/receive", ProductOrderController, :receive
    get "/customers", CustomerController, :index
    post "/customers", CustomerController, :create
    get "/sales/report", SaleController, :report
    get "/sales", SaleController, :index
    get "/sales/:id", SaleController, :show
    post "/sales", SaleController, :create
    post "/sales/:id/payments", SaleController, :add_payment
    post "/sales/:id/cancel", SaleController, :cancel
  end

  # The Tauri webview is served from its own origin. Tenant-owned routes use
  # bearer authentication in the :tenant_api pipeline.
  defp put_desktop_cors_headers(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
    |> Plug.Conn.put_resp_header("access-control-allow-headers", "authorization, content-type")
    |> Plug.Conn.put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pos_server, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PosServerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
