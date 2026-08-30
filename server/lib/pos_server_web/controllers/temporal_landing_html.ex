defmodule PosServerWeb.TemporalLandingHTML do
  use PosServerWeb, :html

  import PosServerWeb.TemporalLanding.Components

  embed_templates "temporal_landing_html/*"
end
