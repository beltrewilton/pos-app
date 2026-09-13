defmodule PosServerWeb.DashboardHTML do
  use PosServerWeb, :html

  import PosServerWeb.PosLayoutComponents

  embed_templates "dashboard_html/*"

  defp workspace_name(%{company_name: company_name}, _user)
       when is_binary(company_name) and company_name != "",
       do: company_name

  defp workspace_name(_company, %{tenant: tenant}) when is_binary(tenant) and tenant != "",
    do: tenant

  defp workspace_name(_company, _user), do: "Workspace"
end
