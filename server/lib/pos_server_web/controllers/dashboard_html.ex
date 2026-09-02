defmodule PosServerWeb.DashboardHTML do
  use PosServerWeb, :html

  import PosServerWeb.DashboardComponents

  embed_templates "dashboard_html/*"
end
