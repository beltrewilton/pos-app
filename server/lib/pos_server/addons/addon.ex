defmodule PosServer.Addons.Addon do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "addons" do
    field :identifier, :string
    field :name, :string
    field :route, :string
    field :icon, :string
    field :handler, :string
    field :installed, :boolean, default: true
    field :enabled, :boolean, default: true
    field :installed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(addon, attrs) do
    addon
    |> cast(attrs, [:identifier, :name, :route, :icon, :handler, :installed, :enabled, :installed_at])
    |> validate_required([:identifier, :name, :route, :icon, :handler, :installed, :enabled, :installed_at])
    |> unique_constraint(:identifier)
    |> unique_constraint(:route)
  end
end
