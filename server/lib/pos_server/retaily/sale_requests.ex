defmodule PosServer.Retaily.SaleRequests.Line do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :product_id, :integer
    field :quantity, :integer
    field :discount, :decimal, default: Decimal.new(0)
    field :discount_type, :string, default: "money"
    field :discount_input, :decimal
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:product_id, :quantity, :discount, :discount_type, :discount_input])
    |> validate_required([:product_id, :quantity, :discount])
    |> validate_number(:product_id, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:discount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:discount_type, ["money", "percentage"])
    |> validate_percentage_input()
  end

  defp validate_percentage_input(changeset) do
    if get_field(changeset, :discount_type) == "percentage" do
      changeset
      |> validate_required(:discount_input)
      |> validate_number(:discount_input, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    else
      changeset
    end
  end
end

defmodule PosServer.Retaily.SaleRequests.Payment do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :amount, :decimal
    field :type, :string
  end

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:amount, :type])
    |> validate_required([:amount, :type])
    |> validate_inclusion(:type, ["CASH", "CC"])
    |> validate_number(:amount, greater_than: 0)
  end
end

defmodule PosServer.Retaily.SaleRequests.Checkout do
  use Ecto.Schema

  import Ecto.Changeset

  alias PosServer.Retaily.SaleRequests.{Line, Payment}

  @primary_key false
  embedded_schema do
    field :store_id, :integer
    field :client_id, :integer
    field :sequence_type, :string
    field :status, :string
    field :sale_type, :string
    field :delivery_charge, :decimal, default: Decimal.new(0)
    field :discount, :decimal, default: Decimal.new(0)
    field :discount_type, :string
    field :discount_input, :decimal
    field :additional_info, :string, default: ""
    embeds_many :lines, Line
    embeds_many :payments, Payment
  end

  def changeset(checkout, attrs) do
    checkout
    |> cast(attrs, [:store_id, :client_id, :sequence_type, :status, :sale_type, :delivery_charge, :discount, :discount_type, :discount_input, :additional_info])
    |> update_change(:additional_info, &String.trim/1)
    |> cast_embed(:lines, required: true)
    |> cast_embed(:payments)
    |> validate_required([:store_id, :client_id, :sequence_type, :status, :sale_type, :delivery_charge])
    |> validate_number(:store_id, greater_than: 0)
    |> validate_number(:client_id, greater_than: 0)
    |> validate_number(:delivery_charge, greater_than_or_equal_to: 0)
    |> validate_number(:discount, greater_than_or_equal_to: 0)
    |> validate_length(:additional_info, max: 1000)
    |> validate_inclusion(:discount_type, ["money", "percentage"])
    |> validate_percentage_input()
    |> validate_inclusion(:sequence_type, ["CF", "VF", "DV"])
    |> validate_inclusion(:status, ["CASH", "CREDIT"])
    |> validate_inclusion(:sale_type, ["IN_SHOP", "FOR_DELIVER"])
    |> validate_credit_payments()
  end

  defp validate_percentage_input(changeset) do
    if get_field(changeset, :discount_type) == "percentage" do
      changeset
      |> validate_required(:discount_input)
      |> validate_number(:discount_input, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    else
      changeset
    end
  end

  defp validate_credit_payments(changeset) do
    if get_field(changeset, :status) == "CREDIT" and get_field(changeset, :payments) != [] do
      add_error(changeset, :payments, "must be empty for credit sales")
    else
      changeset
    end
  end
end
