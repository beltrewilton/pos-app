defmodule PosServerWeb.AddonController do
  use PosServerWeb, :controller

  alias PosServer.Addons
  alias PosServer.Addons.Installer
  alias PosServer.Retaily.InventoryContext

  def index(%{assigns: %{current_scope: %{actor: :admin}}} = conn, _params) do
    tenant = conn.assigns.current_scope.tenant

    with {:ok, layout} <- pos_layout_assigns(conn) do
      render(conn, :index,
        installed: Addons.enabled_for(tenant),
        tenant: tenant,
        scope: layout.scope,
        stores: layout.stores,
        store_id: layout.store_id
      )
    else
      _ -> redirect(conn, to: ~p"/pos")
    end
  end

  def index(conn, _params), do: redirect(conn, to: ~p"/")

  def install_index(%{assigns: %{current_scope: %{actor: :admin}}} = conn, _params) do
    tenant = conn.assigns.current_scope.tenant

    with {:ok, layout} <- pos_layout_assigns(conn) do
      render(conn, :install,
        catalog: Installer.catalog(),
        installed: Addons.enabled_for(tenant),
        tenant: tenant,
        scope: layout.scope,
        stores: layout.stores,
        store_id: layout.store_id
      )
    else
      _ -> redirect(conn, to: ~p"/pos")
    end
  end

  def install_index(conn, _params), do: redirect(conn, to: ~p"/")

  def install(%{assigns: %{current_scope: %{actor: :admin, tenant: tenant}}} = conn, %{
        "identifier" => identifier
      }) do
    case Installer.install(identifier, tenant) do
      :ok ->
        conn
        |> put_flash(:info, "#{identifier} is installed.")
        |> redirect(to: ~p"/pos/addons/install")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Could not install add-on: #{inspect(reason)}")
        |> redirect(to: ~p"/pos/addons/install")
    end
  end

  def install(conn, _params), do: redirect(conn, to: ~p"/")

  def uninstall(%{assigns: %{current_scope: %{actor: :admin, tenant: tenant}}} = conn, %{
        "identifier" => identifier
      }) do
    case Installer.uninstall(identifier, tenant) do
      {:ok, :purged} ->
        conn
        |> put_flash(:info, "#{identifier} was uninstalled and unloaded.")
        |> redirect(to: ~p"/pos/addons/install")

      {:ok, :not_loaded} ->
        conn
        |> put_flash(:info, "#{identifier} was uninstalled.")
        |> redirect(to: ~p"/pos/addons/install")

      {:ok, :still_referenced} ->
        conn
        |> put_flash(
          :info,
          "#{identifier} was uninstalled. Its code will clear after active work finishes."
        )
        |> redirect(to: ~p"/pos/addons/install")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Could not uninstall add-on: #{inspect(reason)}")
        |> redirect(to: ~p"/pos/addons/install")
    end
  end

  def uninstall(conn, _params), do: redirect(conn, to: ~p"/")

  # Runtime registry lookup selects the add-on behind the generic POS route.
  def show(%{assigns: %{current_scope: %{actor: :admin} = scope}} = conn, %{
        "identifier" => identifier
      }) do
    with addon when not is_nil(addon) <- Addons.get_enabled_for(identifier, scope.tenant),
         {:ok, handler} <- Installer.handler(addon),
         {:ok, layout} <- pos_layout_assigns(conn) do
      render(conn, :show,
        addon: addon,
        entrypoint: handler,
        context: addon_context(scope, addon, conn.params),
        scope: layout.scope,
        stores: layout.stores,
        store_id: layout.store_id
      )
    else
      _ -> send_resp(conn, :not_found, "Add-on not found")
    end
  end

  def show(conn, _params), do: redirect(conn, to: ~p"/")

  def legacy_show(conn, %{"identifier" => identifier}) do
    redirect(conn, to: "/pos/addons/#{identifier}")
  end

  def legacy_show(conn, _params), do: redirect(conn, to: ~p"/")

  # The host owns routing, authentication, tenant scope, and the POS shell.
  # Add-ons receive this context and render only their feature content.
  defp addon_context(scope, addon, params) do
    %{
      addon: %{identifier: addon.identifier, route: addon_route(addon)},
      tenant: scope.tenant,
      actor: %{id: scope.actor_id, type: scope.actor},
      host: %{
        layout: :pos,
        content_class: "dashboard-content",
        panel_class: "catalog-panel"
      },
      params: Map.take(params, ["login", "date_from", "date_to"]),
      repo: PosServer.Repo
    }
  end

  defp pos_layout_assigns(conn) do
    scope = conn.assigns.current_scope

    with {:ok, stores} <- InventoryContext.stores(scope) do
      store = selected_store(stores, get_session(conn, :store_id))
      {:ok, %{scope: scope, stores: stores, store_id: store && store.id}}
    end
  end

  defp selected_store(stores, selected_id) do
    Enum.find(stores, &(to_string(&1.id) == to_string(selected_id))) || List.first(stores)
  end

  defp addon_route(addon), do: "/pos/addons/#{addon.identifier}"
end
