defmodule PosServer.Accounts do
  import Ecto.Query, only: [from: 2]

  alias PosServer.Accounts.{Company, User, UserCompany, UserToken}
  alias PosServer.Repo
  alias PosServer.Retaily.Store

  def list_users do
    from(user in User, order_by: [asc: user.name, asc: user.email])
    |> Repo.all()
  end

  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  def get_user(id), do: Repo.get(User, id)

  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Finds or provisions an admin account from verified Google user info."
  def upsert_user_from_google(user_info)
      when is_map(user_info) do
    google_uid = user_info["sub"] || user_info["id"]
    email = user_info["email"]
    name = user_info["name"] || email
    email_verified? = user_info["email_verified"] == true

    with true <- email_verified?,
         true <- is_binary(google_uid) and byte_size(google_uid) > 0,
         true <- is_binary(email) and byte_size(email) > 0 do
      attrs = %{
        email: email,
        name: name,
        google_uid: google_uid,
        google_picture_url: user_info["picture"]
      }

      case Repo.get_by(User, google_uid: google_uid) || Repo.get_by(User, email: email) do
        %User{} = user ->
          user
          |> User.google_oauth_changeset(attrs)
          |> Repo.update()

        nil ->
          create_google_user(attrs)
      end
    else
      _ -> {:error, :invalid_google_user}
    end
  end

  @doc false
  # The desktop/mobile OAuth handoff still requires a tenant-backed account.
  # Browser sign-up deliberately uses `upsert_user_from_google/1` instead.
  def upsert_tauri_user_from_google(user_info)
      when is_map(user_info) do
    google_uid = user_info["sub"] || user_info["id"]
    email = user_info["email"]
    name = user_info["name"] || email
    email_verified? = user_info["email_verified"] == true

    with true <- email_verified?,
         true <- is_binary(google_uid) and byte_size(google_uid) > 0,
         true <- is_binary(email) and byte_size(email) > 0 do
      attrs = %{
        email: email,
        name: name,
        tenant: google_tenant(google_uid),
        google_uid: google_uid,
        google_picture_url: user_info["picture"],
        confirmed_at: DateTime.utc_now(:second)
      }

      case Repo.get_by(User, google_uid: google_uid) || Repo.get_by(User, email: email) do
        %User{} = user ->
          attrs = %{attrs | tenant: user.tenant || attrs.tenant}

          user
          |> User.google_oauth_changeset(attrs)
          |> Repo.update()

        nil ->
          create_tauri_google_user(attrs)
      end
    else
      _ -> {:error, :invalid_google_user}
    end
  end

  defp create_google_user(attrs) do
    %User{}
    |> User.google_oauth_changeset(attrs)
    |> Repo.insert()
  end

  defp create_tauri_google_user(attrs) do
    user_changeset = User.google_oauth_changeset(%User{}, attrs)
    company_changeset = Company.changeset(%Company{}, %{company_name: "#{attrs.name}'s business"})

    cond do
      not user_changeset.valid? ->
        {:error, user_changeset}

      not company_changeset.valid? ->
        {:error, company_changeset}

      true ->
        create_valid_company_user(user_changeset, company_changeset)
    end
  end

  defp google_tenant(google_uid) do
    "google_" <> (:crypto.hash(:sha256, google_uid) |> Base.encode16(case: :lower) |> binary_part(0, 24))
  end

  def confirm_user(%User{confirmed_at: nil} = user) do
    user
    |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  def confirm_user(%User{} = user), do: {:ok, user}

  def change_company(%Company{} = company, attrs \\ %{}), do: Company.changeset(company, attrs)

  def create_company_user(user_attrs, company_attrs) do
    user_changeset = User.changeset(%User{}, user_attrs)
    company_changeset = Company.changeset(%Company{}, company_attrs)

    cond do
      not user_changeset.valid? ->
        {:error, :user, user_changeset}

      not company_changeset.valid? ->
        {:error, :company, company_changeset}

      true ->
        create_valid_company_user(user_changeset, company_changeset)
    end
  end

  def change_user_token(%UserToken{} = user_token, attrs \\ %{}),
    do: UserToken.changeset(user_token, attrs)

  def create_user_token(attrs) do
    attrs =
      attrs
      |> Map.put("context", "session")
      |> Map.put("token", :crypto.strong_rand_bytes(32))

    %UserToken{}
    |> UserToken.changeset(attrs)
    |> Ecto.Changeset.put_change(:token, attrs["token"])
    |> Repo.insert()
  end

  @doc "Encodes a binary session token for the desktop API Authorization header."
  def encode_session_token(%UserToken{token: token}) when is_binary(token) do
    Base.url_encode64(token, padding: false)
  end

  @doc "Returns the user for a valid binary session token, or nil."
  def get_user_by_session_token(token) when is_binary(token) do
    from(user in User,
      join: user_token in UserToken,
      on: user_token.user_id == user.id,
      where: user_token.token == ^token and user_token.context == "session",
      select: user
    )
    |> Repo.one()
  end

  defp create_valid_company_user(user_changeset, company_changeset) do
    case Repo.insert(user_changeset) do
      {:ok, user} ->
        case create_tenant_company(user.tenant, user.id, company_changeset) do
          :ok ->
            {:ok, user}

          {:error, :tenant, reason} ->
            Repo.delete(user)
            {:error, :tenant, reason}
        end

      {:error, changeset} ->
        {:error, :user, changeset}
    end
  end

  defp create_tenant_company(tenant, user_id, company_changeset) do
    case Triplex.create_schema(tenant, Repo, fn created_tenant, repo ->
           with {:ok, _migrations} <- Triplex.migrate(created_tenant, repo) do
             repo.transaction(fn ->
               with {:ok, company} <-
                      repo.insert(company_changeset, prefix: Triplex.to_prefix(created_tenant)),
                    {:ok, _user_company} <-
                      create_user_company(repo, created_tenant, user_id, company.id) do
                 case create_default_store(repo, created_tenant, company.id) do
                   {:ok, _store} -> created_tenant
                   {:error, reason} -> repo.rollback(reason)
                 end
               else
                 {:error, reason} -> repo.rollback(reason)
               end
             end)
           end
         end) do
      {:ok, _tenant} -> :ok
      {:error, reason} -> {:error, :tenant, reason}
    end
  end

  defp create_user_company(repo, tenant, user_id, company_id) do
    %UserCompany{}
    |> UserCompany.changeset(%{user_id: user_id, company_id: company_id})
    |> repo.insert(prefix: Triplex.to_prefix(tenant))
  end

  defp create_default_store(repo, tenant, company_id) do
    %Store{}
    |> Store.changeset(%{name: "Main Store", company_id: to_string(company_id)})
    |> repo.insert(prefix: Triplex.to_prefix(tenant))
  end
end
