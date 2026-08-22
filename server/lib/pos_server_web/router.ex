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

  scope "/", PosServerWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/users", UserLive, :index
    live "/users/new", UserLive, :new
  end

  scope "/api", PosServerWeb do
    pipe_through :api

    get "/health", HealthController, :show
    get "/products", ProductController, :index
  end

  # The Tauri webview is served from its own origin and reads this unauthenticated
  # local API during the initial POS setup.
  defp put_desktop_cors_headers(conn, _opts) do
    Plug.Conn.put_resp_header(conn, "access-control-allow-origin", "*")
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
