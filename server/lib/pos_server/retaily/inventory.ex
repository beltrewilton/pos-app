defmodule PosServer.Retaily.Store do
  use Ecto.Schema

  schema "app_store" do
    field :name, :string
    field :date_create, :naive_datetime
    field :company_id, :string
    field :slogan, :string
    field :logo, :string
    field :address, :string

    has_many :inventory_entries, PosServer.Retaily.Inventory
    has_many :inventory_heads, PosServer.Retaily.InventoryHead
    has_many :received_product_orders, PosServer.Retaily.ProductOrder, foreign_key: :to_store_id
    has_many :product_order_lines, PosServer.Retaily.ProductOrderLine, foreign_key: :to_store_id
    many_to_many :users, PosServer.Retaily.User, join_through: PosServer.Retaily.UserStore
  end
end

defmodule PosServer.Retaily.Inventory do
  use Ecto.Schema

  schema "app_inventory" do
    field :prev_quantity, :integer, default: 0
    field :quantity, :integer
    field :next_quantity, :integer, default: 0
    field :status, :string, default: "quiet"
    field :last_update, :naive_datetime
    field :user_updated, :string

    belongs_to :product, PosServer.Retaily.Product
    belongs_to :store, PosServer.Retaily.Store
  end
end

defmodule PosServer.Retaily.InventoryHead do
  use Ecto.Schema

  schema "app_inventory_head" do
    field :name, :string
    field :date_create, :naive_datetime
    field :date_close, :naive_datetime
    field :status, :integer, default: 0
    field :memo, :string

    belongs_to :store, PosServer.Retaily.Store
  end
end

defmodule PosServer.Retaily.ProductOrder do
  use Ecto.Schema

  schema "product_order" do
    field :name, :string
    field :memo, :string
    field :order_type, :string
    field :user_requester, :string
    field :user_receiver, :string
    field :date_opened, :naive_datetime
    field :date_closed, :naive_datetime
    field :from_origin_id, :integer
    field :status, :string, default: "opened"

    belongs_to :to_store, PosServer.Retaily.Store
    has_many :lines, PosServer.Retaily.ProductOrderLine
    has_many :bulk_order_lines, PosServer.Retaily.BulkOrderLine
  end
end

defmodule PosServer.Retaily.ProductOrderLine do
  use Ecto.Schema

  schema "product_order_line" do
    field :from_origin_id, :integer
    field :quantity, :integer
    field :quantity_observed, :integer
    field :status, :string, default: "pending"
    field :date_create, :naive_datetime
    field :user_receiver, :string
    field :receiver_last_update, :naive_datetime
    field :receiver_memo, :string

    belongs_to :product, PosServer.Retaily.Product
    belongs_to :to_store, PosServer.Retaily.Store
    belongs_to :product_order, PosServer.Retaily.ProductOrder
  end
end

defmodule PosServer.Retaily.BulkOrder do
  use Ecto.Schema

  schema "bulk_order" do
    field :name, :string
    field :memo, :string
    field :date_create, :naive_datetime
    field :user_create, :string

    has_many :lines, PosServer.Retaily.BulkOrderLine
  end
end

defmodule PosServer.Retaily.BulkOrderLine do
  use Ecto.Schema

  schema "bulk_order_line" do
    belongs_to :bulk_order, PosServer.Retaily.BulkOrder
    belongs_to :product_order, PosServer.Retaily.ProductOrder
  end
end
