defmodule PosServerWeb.AddonHTML do
  use PosServerWeb, :html

  import PosServerWeb.DashboardComponents

  embed_templates "addon_html/*"
end
