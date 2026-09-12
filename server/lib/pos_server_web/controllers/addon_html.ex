defmodule PosServerWeb.AddonHTML do
  use PosServerWeb, :html

  import PosServerWeb.DashboardComponents
  import PosServerWeb.PosLayoutComponents

  embed_templates "addon_html/*"
end
