defmodule PosServer.Retaily.Product do
  use Ecto.Schema

  schema "product" do
    field :name, :string
    field :cost, :float
    field :price, :float
    field :margin, :float
    field :code, :string
    field :img_path, :string
    field :date_create, :naive_datetime
    field :image_raw, :string
    field :active, :integer
    field :user_modified, :string
    field :archived, :string, default: "0"

    has_many :inventory_entries, PosServer.Retaily.Inventory
    has_many :pricing_entries, PosServer.Retaily.PricingList
    has_many :order_lines, PosServer.Retaily.ProductOrderLine
  end
end

defmodule PosServer.Retaily.ProductBackup do
  use Ecto.Schema

  schema "product_bck" do
    field :name, :string
    field :cost, :float
    field :price, :float
    field :margin, :float
    field :code, :string
    field :img_path, :string
    field :date_create, :naive_datetime
    field :image_raw, :string
    field :active, :integer
    field :user_modified, :string
  end
end

defmodule PosServer.Retaily.Pricing do
  use Ecto.Schema

  schema "pricing" do
    field :label, :string
    field :user_modified, :string
    field :date_create, :naive_datetime
    field :price_key, :string
    field :status, :integer, default: 1

    has_many :entries, PosServer.Retaily.PricingList
  end
end

defmodule PosServer.Retaily.PricingList do
  use Ecto.Schema

  schema "pricing_list" do
    field :price, :float
    field :user_modified, :string
    field :date_create, :naive_datetime

    belongs_to :product, PosServer.Retaily.Product
    belongs_to :pricing, PosServer.Retaily.Pricing
  end
end

defmodule PosServer.Retaily.Provider do
  use Ecto.Schema

  schema "provider" do
    field :name, :string
    field :date_create, :naive_datetime
  end
end

defmodule PosServer.Retaily.Delivery do
  use Ecto.Schema

  schema "delivery" do
    field :name, :string
    field :value, :float
  end
end

defmodule PosServer.Retaily.Client do
  use Ecto.Schema

  import Ecto.Changeset

  schema "client" do
    field :name, :string
    field :document_id, :string
    field :address, :string
    field :celphone, :string
    field :email, :string
    field :date_create, :naive_datetime
    field :wholesaler, :integer

    def changeset(client, attrs) do
      client
      |> cast(attrs, [:name, :document_id, :address, :celphone, :email, :wholesaler])
      |> validate_required([:name])
    end
  end
end
