defmodule PosServer.Retaily.Sequence do
  use Ecto.Schema

  schema "app_sequence" do
    field :name, :string
    field :code, :string
    field :prefix, :string
    field :fill, :integer
    field :increment_by, :integer
    field :current_seq, :integer
  end
end

defmodule PosServer.Retaily.Sale do
  use Ecto.Schema

  schema "sale" do
    field :amount, :float
    field :sub, :float
    field :discount, :float
    field :tax_amount, :float
    field :delivery_charge, :float
    field :sequence, :string
    field :sequence_type, :string
    field :status, :string
    field :sale_type, :string
    field :date_create, :naive_datetime
    field :login, :string
    field :client_id, :integer, default: 0
    field :store_id, :integer, default: 0
    field :additional_info, :string

    # The MySQL schema declares no foreign keys for sale_line or sale_paid.
    # Associations are intentionally omitted rather than inferred.
  end
end

defmodule PosServer.Retaily.SaleLine do
  use Ecto.Schema

  schema "sale_line" do
    field :amount, :float
    field :tax_amount, :float
    field :discount, :float
    field :quantity, :float
    field :total_amount, :float
    field :sale_id, :integer, default: 0
    field :product_id, :integer
  end
end

defmodule PosServer.Retaily.SalePaid do
  use Ecto.Schema

  schema "sale_paid" do
    field :amount, :float
    field :type, :string
    field :date_create, :naive_datetime
    field :sale_id, :integer, default: 0
  end
end
