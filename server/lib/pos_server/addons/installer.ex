defmodule PosServer.Addons.Installer do
  @moduledoc """
  Discovery and loading boundary for local add-ons.

  Add-on source remains outside the Phoenix project. The host discovers add-ons
  by scanning the configured add-ons root for `*/addon.ex` and only accepts safe
  identifier-shaped directory names.
  """

  alias PosServer.Addons

  @addons_root Path.expand("../../../../../addons-pos-app", __DIR__)

  def available do
    @addons_root
    |> discovered_sources()
    |> Enum.map(fn {identifier, _path} -> identifier end)
  end

  def catalog do
    @addons_root
    |> discovered_sources()
    |> Enum.flat_map(fn {identifier, path} ->
      case catalog_entry(identifier, path) do
        {:ok, addon} -> [addon]
        {:error, _reason} -> []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end

  def install(identifier, tenant) when is_binary(tenant) and tenant != "" do
    if Addons.installed?(identifier, tenant),
      do: :ok,
      else: discover_load_and_register(identifier, tenant)
  end

  def install(_identifier, _tenant), do: {:error, :missing_tenant}

  def uninstall(identifier, tenant) do
    case Addons.get_enabled_for(identifier, tenant) do
      nil -> {:error, :unknown_addon}
      addon -> unload_and_unregister(addon)
    end
  end

  def handler(addon) do
    with {:ok, path} <- source_path(addon.identifier),
         true <- File.regular?(path),
         handler <- revision_module(addon.identifier, addon.tenant, addon.revision),
         true <- addon.handler == Atom.to_string(handler),
         true <- ensure_entrypoint(path, handler) do
      {:ok, handler}
    else
      false -> {:error, :invalid_addon_handler}
      {:error, reason} -> {:error, reason}
    end
  rescue
    ArgumentError -> {:error, :invalid_addon_handler}
  end

  defp discover_load_and_register(identifier, tenant) do
    with {:ok, path} <- source_path(identifier),
         true <- File.regular?(path),
         {:ok, source} <- File.read(path),
         revision <- revision_for(source),
         handler <- revision_module(identifier, tenant, revision),
         modules when is_list(modules) <- compile_source(source, path, handler),
         {:ok, module} <- addon_module(modules),
         manifest when is_map(manifest) <- module.manifest(),
         :ok <- validate_manifest(manifest, identifier, handler),
         {:ok, _addon} <- Addons.register(registration_attrs(manifest, tenant, revision, handler)) do
      :ok
    else
      false -> {:error, :missing_addon_source}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_addon, other}}
    end
  end

  defp unload_and_unregister(addon) do
    handler = revision_module(addon.identifier, addon.tenant, addon.revision)

    if addon.handler == Atom.to_string(handler) do
      # Source files may define nested helper modules. Unload leaves before
      # their root namespace, always using soft_purge/1 (never purge/1).
      case safely_unload_namespace(handler) do
        :purged -> unregister(addon, :purged)
        :still_referenced -> unregister(addon, :still_referenced)
      end
    else
      {:error, :invalid_addon_handler}
    end
  end

  defp safely_unload_namespace(handler) do
    handler
    |> namespace_modules()
    |> Enum.reduce(:purged, fn module, status ->
      case safely_unload(module) do
        :purged -> status
        :still_referenced -> :still_referenced
      end
    end)
  end

  defp namespace_modules(handler) do
    namespace = Atom.to_string(handler)

    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(fn module ->
      module_name = Atom.to_string(module)
      module_name == namespace or String.starts_with?(module_name, namespace <> ".")
    end)
    |> Enum.sort_by(&(Atom.to_string(&1) |> byte_size()), :desc)
  end

  defp safely_unload(handler) do
    case :code.is_loaded(handler) do
      false ->
        :purged

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

  # Reload only when an installed add-on exposes an older host contract.
  # Normal requests do not recompile the external source.
  defp ensure_entrypoint(path, handler) do
    if function_exported?(handler, :render, 1) do
      true
    else
      compile_revision(path, handler)
      function_exported?(handler, :render, 1)
    end
  end

  defp compile_revision(path, handler) do
    with {:ok, source} <- File.read(path) do
      compile_source(source, path, handler)
    else
      _ -> []
    end
  end

  defp compile_source(source, path, handler) do
    source
    |> rewrite_root_module(handler)
    |> Code.compile_string(path)
  end

  defp rewrite_root_module(source, handler) do
    Regex.replace(~r/defmodule\s+[A-Za-z0-9_.]+\s+do/, source, "defmodule #{inspect(handler)} do",
      global: false
    )
  end

  defp revision_module(identifier, tenant, revision) do
    tenant_part =
      tenant |> String.replace(~r/[^a-zA-Z0-9]/, "_") |> Macro.camelize() |> String.slice(0, 40)

    tenant_hash =
      :crypto.hash(:sha256, tenant) |> Base.encode16(case: :lower) |> String.slice(0, 10)

    addon_part = identifier |> String.replace(~r/[^a-zA-Z0-9]/, "_") |> Macro.camelize()
    revision_part = revision |> String.replace("-", "")

    Module.concat([
      PosServer,
      :TenantAddons,
      "Tenant#{tenant_part}#{tenant_hash}",
      "#{addon_part}Revision#{revision_part}"
    ])
  end

  # Reinstalling unchanged source reuses its module name. A code change gets a
  # new immutable revision namespace, limiting new atoms to real source versions.
  defp revision_for(source) do
    :crypto.hash(:sha256, source)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp source_path(identifier) do
    if valid_identifier?(identifier) do
      path = Path.join([@addons_root, identifier, "addon.ex"])

      if File.regular?(path) do
        {:ok, path}
      else
        {:error, :unknown_addon}
      end
    else
      {:error, :unknown_addon}
    end
  end

  defp discovered_sources(root) do
    root
    |> Path.join("*/addon.ex")
    |> Path.wildcard()
    |> Enum.map(fn path -> {path |> Path.dirname() |> Path.basename(), path} end)
    |> Enum.filter(fn {identifier, _path} -> valid_identifier?(identifier) end)
  end

  defp valid_identifier?(identifier) when is_binary(identifier),
    do: Regex.match?(~r/\A[a-zA-Z0-9_]+\z/, identifier)

  defp valid_identifier?(_identifier), do: false

  defp catalog_entry(identifier, path) do
    with {:ok, source} <- File.read(path),
         revision <- revision_for(source),
         handler <- revision_module(identifier, "__catalog__", revision),
         modules when is_list(modules) <- compile_source(source, path, handler),
         {:ok, module} <- addon_module(modules),
         manifest when is_map(manifest) <- module.manifest(),
         :ok <- validate_manifest(manifest, identifier, handler) do
      {:ok,
       %{
         identifier: manifest.identifier,
         path: path,
         name: manifest.name,
         icon: manifest.icon,
         route: "/pos/addons/" <> manifest.identifier,
         description: Map.get(manifest, :description, "Add-on for this workspace.")
       }}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_addon, other}}
    end
  end

  defp addon_module(modules) do
    case Enum.find(modules, fn {module, _binary} -> function_exported?(module, :manifest, 0) end) do
      {module, _binary} -> {:ok, module}
      nil -> {:error, :missing_manifest}
    end
  end

  defp validate_manifest(
         %{identifier: manifest_identifier, route: route, handler: manifest_handler},
         identifier,
         handler
       )
       when is_atom(manifest_handler) do
    if manifest_identifier == identifier and manifest_handler == handler and
         route in ["/pos/addons/" <> identifier, "/addons/" <> identifier] do
      :ok
    else
      {:error, :invalid_manifest}
    end
  end

  defp validate_manifest(_, _, _), do: {:error, :invalid_manifest}

  defp registration_attrs(manifest, tenant, revision, handler) do
    %{
      identifier: manifest.identifier,
      name: manifest.name,
      route: "/pos/addons/" <> manifest.identifier,
      icon: manifest.icon,
      handler: Atom.to_string(handler),
      tenant: tenant,
      revision: revision,
      installed: true,
      enabled: true,
      installed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
