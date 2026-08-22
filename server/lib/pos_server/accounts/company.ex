defmodule PosServer.Accounts.Company do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "company" do
    field :rnc, :string
    field :company_name, :string
    field :access_token, :string
    field :active, :boolean, default: true
    field :connected, :boolean, default: false
    field :odoo_url, :string
    field :odoo_db, :string
    field :odoo_user, :string
    field :odoo_apikey, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(company, attrs) do
    company
    |> cast(attrs, [:company_name, :rnc])
    |> validate_required([:company_name])
  end
end
