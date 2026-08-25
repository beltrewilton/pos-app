defmodule PosServer.Authentication do
  @moduledoc "Unified login and bearer-token authentication for tenant admins and employees."

  import Ecto.Query

  alias PosServer.Accounts.{Scope, User}
  alias PosServer.{Accounts, Password, Repo}
  alias PosServer.Retaily.Scope, as: EmployeeScope
  alias PosServer.Retaily.User, as: Employee
  alias PosServer.Retaily.UserStore

  @salt "api-session"

  def login(%{"identifier" => identifier, "password" => password})
      when is_binary(identifier) and is_binary(password) do
    IO.inspect(identifier, label: "login submitted identifier")

    result =
      case Accounts.get_user_by_email(identifier) do
        %User{} = admin ->
          IO.inspect(admin_lookup_summary(admin), label: "login user lookup")
          authenticate_admin(admin, password)

        nil ->
          IO.inspect(%{actor: :employee, found?: false}, label: "login user lookup")
          authenticate_employee(identifier, password)
      end

    IO.inspect(login_result_summary(result), label: "login authentication result")
    result
  end

  def login(_), do: {:error, :invalid_credentials}

  def authenticate(token) when is_binary(token) do
    with {:ok, payload} <-
           Phoenix.Token.verify(PosServerWeb.Endpoint, @salt, token, max_age: 86_400),
         {:ok, scope} <- scope_from_payload(payload) do
      {:ok, scope}
    else
      _ -> {:error, :unauthorized}
    end
  end

  def authenticate(_), do: {:error, :unauthorized}

  defp authenticate_admin(admin, password) do
    verified? = Password.verify(password, admin.hashed_password)
    IO.inspect(verified?, label: "login password verification")

    if verified? do
      scope = Scope.for_user(admin)
      {:ok, issue(scope), scope}
    else
      {:error, :invalid_credentials}
    end
  end

  defp authenticate_employee(username, password) do
    tenants = Triplex.all(Repo) |> Enum.filter(&valid_tenant?/1)
    IO.inspect(tenants, label: "login tenant discovery")

    tenants
    |> Enum.reduce_while({:error, :invalid_credentials}, fn tenant, _result ->
      case authenticate_employee_in_tenant(tenant, username, password) do
        {:ok, _, _} = authenticated -> {:halt, authenticated}
        {:error, :invalid_credentials} -> {:cont, {:error, :invalid_credentials}}
      end
    end)
  end

  defp authenticate_employee_in_tenant(tenant, username, password) do
    employee = Repo.one(from(user in Employee, where: user.username == ^username), prefix: tenant)

    IO.inspect(employee_lookup_summary(employee, tenant), label: "login user lookup")

    verified? =
      case employee do
        %Employee{is_active: 1, password: stored_password} when is_binary(stored_password) ->
          Password.verify(password, stored_password)

        _ ->
          false
      end

    IO.inspect(verified?, label: "login password verification")

    case {employee, verified?} do
      {%Employee{is_active: 1} = employee, true} ->
        employee = Repo.update!(Ecto.Changeset.change(employee, last_login: now()), prefix: tenant)
        scope = employee_scope(employee, tenant)
        {:ok, issue(scope), scope}

      _ ->
        {:error, :invalid_credentials}
    end
  end

  # Temporary login diagnostics intentionally exclude password material, hashes, and tokens.
  defp admin_lookup_summary(admin),
    do: %{actor: :admin, found?: true, id: admin.id, tenant: admin.tenant}

  defp employee_lookup_summary(nil, tenant),
    do: %{actor: :employee, found?: false, tenant: tenant}

  defp employee_lookup_summary(employee, tenant),
    do: %{actor: :employee, found?: true, id: employee.id, active?: employee.is_active == 1, tenant: tenant}

  defp login_result_summary({:ok, _token, scope}),
    do: %{authenticated?: true, actor: scope.actor, actor_id: scope.actor_id, tenant: scope.tenant}

  defp login_result_summary({:error, reason}), do: %{authenticated?: false, reason: reason}

  defp scope_from_payload(%{"actor" => "admin", "id" => id, "tenant" => tenant}) do
    case Repo.get(User, id) do
      %User{tenant: ^tenant} = admin -> {:ok, Scope.for_user(admin)}
      _ -> {:error, :unauthorized}
    end
  end

  defp scope_from_payload(%{"actor" => "employee", "id" => id, "tenant" => tenant})
       when is_integer(id) do
    if valid_tenant?(tenant) do
      case Repo.get(Employee, id, prefix: tenant) do
        %Employee{is_active: 1} = employee -> {:ok, employee_scope(employee, tenant)}
        _ -> {:error, :unauthorized}
      end
    else
      {:error, :unauthorized}
    end
  end

  defp scope_from_payload(_), do: {:error, :unauthorized}

  defp employee_scope(employee, tenant) do
    scopes =
      Repo.all(
        from(scope in EmployeeScope, where: scope.user_id == ^employee.id, select: scope.name),
        prefix: tenant
      )
      |> Enum.uniq()

    store_ids =
      Repo.all(
        from(link in UserStore, where: link.user_id == ^employee.id, select: link.store_id),
        prefix: tenant
      )

    %PosServer.Accounts.Scope{
      user: %{name: employee.username, tenant: tenant},
      tenant: tenant,
      actor: :employee,
      actor_id: employee.id,
      login: employee.username,
      pic: employee.pic,
      scopes: scopes,
      store_ids: store_ids
    }
  end

  defp issue(scope),
    do:
      Phoenix.Token.sign(PosServerWeb.Endpoint, @salt, %{
        "actor" => Atom.to_string(scope.actor),
        "id" => scope.actor_id,
        "tenant" => scope.tenant
      })

  defp valid_tenant?(tenant) when is_binary(tenant),
    do: String.match?(tenant, ~r/^[a-z][a-z0-9_]{2,62}$/)

  defp valid_tenant?(_), do: false
  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
