defmodule PosServer.Authentication do
  @moduledoc "Unified login and bearer-token authentication for tenant admins and employees."

  import Ecto.Query

  alias PosServer.Accounts.{Scope, User}
  alias PosServer.{Accounts, Repo}
  alias PosServer.Retaily.Scope, as: EmployeeScope
  alias PosServer.Retaily.User, as: Employee
  alias PosServer.Retaily.UserStore

  @salt "api-session"

  def login(%{"identifier" => identifier, "password" => password} = attrs)
      when is_binary(identifier) and is_binary(password) do
    case Accounts.get_user_by_email(identifier) do
      %User{} = admin -> authenticate_admin(admin, password)
      nil -> authenticate_employee(attrs["tenant"], identifier, password)
    end
  end

  def login(_), do: {:error, :invalid_credentials}

  def authenticate(token) when is_binary(token) do
    with {:ok, payload} <- Phoenix.Token.verify(PosServerWeb.Endpoint, @salt, token, max_age: 86_400),
         {:ok, scope} <- scope_from_payload(payload) do
      {:ok, scope}
    else
      _ -> {:error, :unauthorized}
    end
  end

  def authenticate(_), do: {:error, :unauthorized}

  defp authenticate_admin(admin, password) do
    if Bcrypt.verify_pass(password, admin.hashed_password) do
      scope = Scope.for_user(admin)
      {:ok, issue(scope), scope}
    else
      {:error, :invalid_credentials}
    end
  end

  defp authenticate_employee(tenant, username, password) when is_binary(tenant) do
    with true <- valid_tenant?(tenant),
         %Employee{is_active: 1} = employee <- Repo.one(from(user in Employee, where: user.username == ^username), prefix: tenant),
         true <- is_binary(employee.password),
         true <- Bcrypt.verify_pass(password, employee.password) do
      employee = Repo.update!(Ecto.Changeset.change(employee, last_login: now()), prefix: tenant)
      scope = employee_scope(employee, tenant)
      {:ok, issue(scope), scope}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  defp authenticate_employee(_, _, _), do: {:error, :invalid_credentials}

  defp scope_from_payload(%{"actor" => "admin", "id" => id, "tenant" => tenant}) do
    case Repo.get(User, id) do
      %User{tenant: ^tenant} = admin -> {:ok, Scope.for_user(admin)}
      _ -> {:error, :unauthorized}
    end
  end

  defp scope_from_payload(%{"actor" => "employee", "id" => id, "tenant" => tenant}) when is_integer(id) do
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
    scopes = Repo.all(from(scope in EmployeeScope, where: scope.user_id == ^employee.id, select: scope.name), prefix: tenant) |> Enum.uniq()
    store_ids = Repo.all(from(link in UserStore, where: link.user_id == ^employee.id, select: link.store_id), prefix: tenant)

    %PosServer.Accounts.Scope{user: %{name: employee.username, tenant: tenant}, tenant: tenant, actor: :employee,
      actor_id: employee.id, login: employee.username, scopes: scopes, store_ids: store_ids}
  end

  defp issue(scope), do: Phoenix.Token.sign(PosServerWeb.Endpoint, @salt, %{"actor" => Atom.to_string(scope.actor), "id" => scope.actor_id, "tenant" => scope.tenant})
  defp valid_tenant?(tenant) when is_binary(tenant), do: String.match?(tenant, ~r/^[a-z][a-z0-9_]{2,62}$/)
  defp valid_tenant?(_), do: false
  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
