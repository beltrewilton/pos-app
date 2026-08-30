defmodule PosServerWeb.LandingHTML do
  use PosServerWeb, :html

  import PosServerWeb.Landing.Components

  embed_templates "landing_html/*"
end
