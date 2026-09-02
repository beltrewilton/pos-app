defmodule PosServer.Addons do
  @moduledoc "Persistent registry for installed add-ons."

  import Ecto.Query

  alias PosServer.Addons.Addon
  alias PosServer.Repo

  def enabled_for(tenant) when is_binary(tenant) do
    Repo.all(from addon in Addon, where: addon.tenant == ^tenant and addon.installed and addon.enabled, order_by: [asc: addon.name])
  end

  def enabled_for(_tenant), do: []

  def get_enabled_for(identifier, tenant) when is_binary(tenant) do
    Repo.one(from addon in Addon, where: addon.identifier == ^identifier and addon.tenant == ^tenant and addon.installed and addon.enabled)
  end

  def get_enabled_for(_identifier, _tenant), do: nil

  def installed?(identifier, tenant) when is_binary(tenant), do: Repo.exists?(from addon in Addon, where: addon.identifier == ^identifier and addon.tenant == ^tenant)
  def installed?(_identifier, _tenant), do: false

  def register(attrs) do
    %Addon{}
    |> Addon.changeset(attrs)
    |> Repo.insert()
  end

  def unregister(addon), do: Repo.delete(addon)
end
