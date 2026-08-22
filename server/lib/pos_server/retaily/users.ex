defmodule PosServer.Retaily.User do
  use Ecto.Schema

  schema "app_users" do
    field :username, :string
    field :password, :string
    field :first_name, :string
    field :last_name, :string
    field :is_active, :integer
    field :date_joined, :naive_datetime
    field :last_login, :naive_datetime
    field :pic, :string

    has_many :user_stores, PosServer.Retaily.UserStore
    has_many :scopes, PosServer.Retaily.Scope
    many_to_many :stores, PosServer.Retaily.Store, join_through: PosServer.Retaily.UserStore
  end
end

defmodule PosServer.Retaily.UserStore do
  use Ecto.Schema

  @primary_key false

  schema "app_user_store" do
    belongs_to :user, PosServer.Retaily.User, primary_key: true
    belongs_to :store, PosServer.Retaily.Store, primary_key: true
  end
end

defmodule PosServer.Retaily.Scope do
  use Ecto.Schema

  schema "scopes" do
    field :name, :string

    belongs_to :user, PosServer.Retaily.User
  end
end

defmodule PosServer.Retaily.ScopeList do
  use Ecto.Schema

  schema "scope_list" do
    field :name, :string
  end
end
