defmodule PosServerWeb.DashboardController do
  use PosServerWeb, :controller

  alias PosServer.{Accounts, Authentication}
  alias PosServer.Accounts.Company

  def index(%{assigns: %{current_scope: %{actor: :admin, actor_id: user_id}}} = conn, _params) do
    case Accounts.get_user(user_id) do
      nil -> redirect(conn, to: ~p"/")
      user -> render_dashboard(conn, user)
    end
  end

  def index(conn, _params), do: redirect(conn, to: ~p"/")

  def create(%{assigns: %{current_scope: %{actor: :admin, actor_id: user_id}}} = conn, params) do
    case Accounts.get_user(user_id) do
      nil ->
        redirect(conn, to: ~p"/")

      user ->
        tenant_attrs = attrs_param(params, "tenant")
        company_attrs = attrs_param(params, "company")

        case Accounts.create_tenant_for_user(user, tenant_attrs, company_attrs) do
          {:ok, updated_user} ->
            {:ok, session_token, _scope} = Authentication.log_in_user(updated_user)

            conn
            |> configure_session(renew: true)
            |> put_session(:user_token, session_token)
            |> put_flash(:info, "Your workspace has been created.")
            |> redirect(to: ~p"/dash")

          {:error, :tenant, changeset} ->
            render_dashboard(conn, user, tenant_changeset: changeset, company_attrs: company_attrs)

          {:error, :company, changeset} ->
            render_dashboard(conn, user, tenant_attrs: tenant_attrs, company_changeset: changeset)

          {:error, :unconfirmed} ->
            conn
            |> put_flash(:error, "Your account must be confirmed before creating a workspace.")
            |> redirect(to: ~p"/dash")

          {:error, :tenant_exists} ->
            conn
            |> put_flash(:error, "This account already has a workspace.")
            |> redirect(to: ~p"/dash")

          {:error, :provisioning, _reason} ->
            conn
            |> put_flash(:error, "The workspace could not be created. Please try again.")
            |> redirect(to: ~p"/dash")
        end
    end
  end

  def create(conn, _params), do: redirect(conn, to: ~p"/")

  defp render_dashboard(conn, user, opts \\ []) do
    tenant_changeset = Keyword.get(opts, :tenant_changeset, Accounts.change_tenant(user, Keyword.get(opts, :tenant_attrs, %{})))
    company_changeset = Keyword.get(opts, :company_changeset, Accounts.change_company(%Company{}, Keyword.get(opts, :company_attrs, %{})))

    render(conn, :index,
      user: user,
      company: Accounts.get_company_for_user(user),
      tenant_form: Phoenix.Component.to_form(tenant_changeset, as: :tenant),
      company_form: Phoenix.Component.to_form(company_changeset, as: :company)
    )
  end

  defp attrs_param(params, key) do
    case Map.get(params, key) do
      attrs when is_map(attrs) -> attrs
      _ -> %{}
    end
  end
end
