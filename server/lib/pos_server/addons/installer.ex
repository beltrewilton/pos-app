defmodule PosServer.Addons.Installer do
  @moduledoc """
  Discovery and loading boundary for the local first-version add-on catalog.

  Add-on source remains outside the Phoenix project. This prototype intentionally
  recognizes only explicitly catalogued identifiers; it must not load a path
  supplied by a request.
  """

  alias PosServer.Addons

  @catalog %{
    "simply_print" => Path.expand("../../../../../addons-pos-app/simply_print/addon.ex", __DIR__)
  }

  def available, do: Map.keys(@catalog)

  def install(identifier) do
    if Addons.installed?(identifier), do: :ok, else: discover_load_and_register(identifier)
  end

  def uninstall(identifier) do
    case Addons.get_enabled(identifier) do
      nil -> {:error, :unknown_addon}
      addon -> unload_and_unregister(addon)
    end
  end

  def handler(addon) do
    with {:ok, path} <- source_path(addon.identifier),
         true <- File.regular?(path),
         _ <- Code.require_file(path),
         handler <- String.to_existing_atom(addon.handler),
         true <- ensure_page_handler(path, handler) do
      {:ok, handler}
    else
      false -> {:error, :invalid_addon_handler}
      {:error, reason} -> {:error, reason}
    end
  rescue
    ArgumentError -> {:error, :invalid_addon_handler}
  end

  defp discover_load_and_register(identifier) do
    with {:ok, path} <- source_path(identifier),
         true <- File.regular?(path),
         modules when is_list(modules) <- Code.compile_file(path),
         {:ok, module} <- addon_module(modules),
         manifest when is_map(manifest) <- module.manifest(),
         :ok <- validate_manifest(manifest, identifier),
         {:ok, _addon} <- Addons.register(registration_attrs(manifest)) do
      :ok
    else
      false -> {:error, :missing_addon_source}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_addon, other}}
    end
  end

  defp unload_and_unregister(addon) do
    case handler_atom(addon.handler) do
      :not_loaded -> unregister(addon, :not_loaded)

      {:ok, handler} ->
        # delete/1 makes current code old. soft_purge/1 only removes that old
        # code if no process still references it; unlike purge/1, it never kills.
        case safely_unload(handler) do
          :purged -> unregister(addon, :purged)
          :still_referenced -> unregister(addon, :still_referenced)
        end
    end
  end

  defp safely_unload(handler) do
    case :code.is_loaded(handler) do
      false -> :purged

      _loaded ->
        # A previous replacement may have left old code behind. Do not delete
        # the current version unless that old version can be safely removed.
        if :code.soft_purge(handler) and :code.delete(handler) do
          if :code.soft_purge(handler), do: :purged, else: :still_referenced
        else
          :still_referenced
        end
    end
  end

  defp unregister(addon, unload_status) do
    case Addons.unregister(addon) do
      {:ok, _addon} -> {:ok, unload_status}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handler_atom(handler) do
    {:ok, String.to_existing_atom(handler)}
  rescue
    ArgumentError -> :not_loaded
  end

  # Reload only when an installed add-on exposes an older host contract.
  # Normal requests do not recompile the external source.
  defp ensure_page_handler(path, handler) do
    if function_exported?(handler, :page, 2) do
      true
    else
      Code.compile_file(path)
      function_exported?(handler, :page, 2)
    end
  end

  defp source_path(identifier) do
    case Map.fetch(@catalog, identifier) do
      {:ok, path} -> {:ok, path}
      :error -> {:error, :unknown_addon}
    end
  end

  defp addon_module(modules) do
    case Enum.find(modules, fn {module, _binary} -> function_exported?(module, :manifest, 0) end) do
      {module, _binary} -> {:ok, module}
      nil -> {:error, :missing_manifest}
    end
  end

  defp validate_manifest(%{identifier: identifier, route: "/addons/" <> identifier, handler: handler}, identifier)
       when is_atom(handler), do: :ok

  defp validate_manifest(_, _), do: {:error, :invalid_manifest}

  defp registration_attrs(manifest) do
    %{
      identifier: manifest.identifier,
      name: manifest.name,
      route: manifest.route,
      icon: manifest.icon,
      handler: Atom.to_string(manifest.handler),
      installed: true,
      enabled: true,
      installed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
