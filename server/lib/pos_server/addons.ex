defmodule PosServer.Addons do
  @moduledoc "Persistent registry for installed add-ons."

  import Ecto.Query

  alias PosServer.Addons.Addon
  alias PosServer.Repo

  def enabled do
    Repo.all(from addon in Addon, where: addon.installed and addon.enabled, order_by: [asc: addon.name])
  end

  def get_enabled(identifier) do
    Repo.one(from addon in Addon, where: addon.identifier == ^identifier and addon.installed and addon.enabled)
  end

  def installed?(identifier), do: Repo.exists?(from addon in Addon, where: addon.identifier == ^identifier)

  def register(attrs) do
    %Addon{}
    |> Addon.changeset(attrs)
    |> Repo.insert()
  end

  def unregister(addon), do: Repo.delete(addon)
end
