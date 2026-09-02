defmodule PosServer.Repo.Migrations.UpgradeAddonsRegistry do
  use Ecto.Migration

  def up do
    rename table(:addons), :slug, to: :identifier
    rename table(:addons), :module, to: :handler

    alter table(:addons) do
      add :route, :string, null: false, default: ""
      add :installed, :boolean, null: false, default: true
      add :installed_at, :utc_datetime
    end

    execute "UPDATE addons SET route = '/addons/' || identifier, installed_at = COALESCE(inserted_at, NOW())"

    alter table(:addons) do
      modify :route, :string, null: false, default: nil
      modify :installed_at, :utc_datetime, null: false
    end

    execute "ALTER INDEX addons_slug_index RENAME TO addons_identifier_index"
    create unique_index(:addons, [:route])
  end

  def down do
    drop_if_exists unique_index(:addons, [:route])
    execute "ALTER INDEX addons_identifier_index RENAME TO addons_slug_index"

    alter table(:addons) do
      remove :installed_at
      remove :installed
      remove :route
    end

    rename table(:addons), :handler, to: :module
    rename table(:addons), :identifier, to: :slug
  end
end
