defmodule PosServerWeb.AddonController do
  use PosServerWeb, :controller

  alias PosServer.Addons
  alias PosServer.Addons.Installer

  def install_index(%{assigns: %{current_scope: %{actor: :admin}}} = conn, _params) do
    tenant = conn.assigns.current_scope.tenant
    render(conn, :install, available: Installer.available(), installed: Addons.enabled_for(tenant), tenant: tenant)
  end

  def install_index(conn, _params), do: redirect(conn, to: ~p"/")

  def install(%{assigns: %{current_scope: %{actor: :admin, tenant: tenant}}} = conn, %{"identifier" => identifier}) do
    case Installer.install(identifier, tenant) do
      :ok -> conn |> put_flash(:info, "#{identifier} is installed.") |> redirect(to: ~p"/addons/install")
      {:error, reason} -> conn |> put_flash(:error, "Could not install add-on: #{inspect(reason)}") |> redirect(to: ~p"/addons/install")
    end
  end

  def install(conn, _params), do: redirect(conn, to: ~p"/")

  def uninstall(%{assigns: %{current_scope: %{actor: :admin, tenant: tenant}}} = conn, %{"identifier" => identifier}) do
    case Installer.uninstall(identifier, tenant) do
      {:ok, :purged} -> conn |> put_flash(:info, "#{identifier} was uninstalled and unloaded.") |> redirect(to: ~p"/addons/install")
      {:ok, :not_loaded} -> conn |> put_flash(:info, "#{identifier} was uninstalled.") |> redirect(to: ~p"/addons/install")
      {:ok, :still_referenced} -> conn |> put_flash(:info, "#{identifier} was uninstalled. Its code will clear after active work finishes.") |> redirect(to: ~p"/addons/install")
      {:error, reason} -> conn |> put_flash(:error, "Could not uninstall add-on: #{inspect(reason)}") |> redirect(to: ~p"/addons/install")
    end
  end

  def uninstall(conn, _params), do: redirect(conn, to: ~p"/")

  # The static Phoenix route ends here. Runtime registry lookup selects the add-on.
  def show(%{assigns: %{current_scope: %{actor: :admin} = scope}} = conn, %{"identifier" => identifier}) do
    with addon when not is_nil(addon) <- Addons.get_enabled_for(identifier, scope.tenant),
         {:ok, handler} <- Installer.handler(addon) do
      render(conn, :show, addon: addon, entrypoint: handler, context: addon_context(scope, addon, conn.params))
    else
      _ -> send_resp(conn, :not_found, "Add-on not found")
    end
  end

  def show(conn, _params), do: redirect(conn, to: ~p"/")

  # This is the complete host-to-add-on contract for the first version. The
  # host owns the dashboard shell; the add-on owns its feature content.
  defp addon_context(scope, addon, params) do
    %{
      addon: %{identifier: addon.identifier, route: addon.route},
      tenant: scope.tenant,
      actor: %{id: scope.actor_id, type: scope.actor},
      params: Map.take(params, ["login", "date_from", "date_to"]),
      repo: PosServer.Repo
    }
  end
end
