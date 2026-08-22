defmodule PosServer.Repo.Migrations.HardenSalesIntegrity do
  use Ecto.Migration

  def up do
    alter table(:sale) do
      modify :amount, :decimal, precision: 14, scale: 2
      modify :sub, :decimal, precision: 14, scale: 2
      modify :discount, :decimal, precision: 14, scale: 2
      modify :tax_amount, :decimal, precision: 14, scale: 2
      modify :delivery_charge, :decimal, precision: 14, scale: 2
    end

    alter table(:sale_line) do
      modify :amount, :decimal, precision: 14, scale: 2
      modify :tax_amount, :decimal, precision: 14, scale: 2
      modify :discount, :decimal, precision: 14, scale: 2
      modify :total_amount, :decimal, precision: 14, scale: 2
      modify :sale_id, references(:sale, type: :bigint, on_delete: :restrict)
      modify :product_id, references(:product, type: :bigint, on_delete: :restrict)
    end

    alter table(:sale_paid) do
      modify :amount, :decimal, precision: 14, scale: 2
      modify :sale_id, references(:sale, type: :bigint, on_delete: :restrict)
    end

    create unique_index(:app_inventory, [:product_id, :store_id])
    create index(:sale_line, [:sale_id])
    create index(:sale_paid, [:sale_id])
    create unique_index(:sale, [:sequence_type, :sequence])
  end

  def down do
    drop unique_index(:sale, [:sequence_type, :sequence])
    drop index(:sale_paid, [:sale_id])
    drop index(:sale_line, [:sale_id])
    drop unique_index(:app_inventory, [:product_id, :store_id])

    alter table(:sale_paid) do
      modify :sale_id, :bigint
      modify :amount, :float
    end

    alter table(:sale_line) do
      modify :product_id, :bigint
      modify :sale_id, :bigint
      modify :total_amount, :float
      modify :discount, :float
      modify :tax_amount, :float
      modify :amount, :float
    end

    alter table(:sale) do
      modify :delivery_charge, :float
      modify :tax_amount, :float
      modify :discount, :float
      modify :sub, :float
      modify :amount, :float
    end
  end
end
