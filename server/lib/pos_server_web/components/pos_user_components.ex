defmodule PosServerWeb.PosUserComponents do
  @moduledoc false
  use PosServerWeb, :html

  alias PosServer.Accounts.Scope

  attr :users, :list, required: true
  attr :filter, :string, required: true
  attr :options, :map, required: true
  attr :scope, :map, required: true
  attr :status, :string, required: true

  def user_list(assigns) do
    ~H"""
    <section id="users-screen" class="users-screen application-screen" aria-labelledby="users-title">
      <header class="topbar users-header">
        <div class="brand-lockup">
          <span class="brand-mark" aria-hidden="true">E</span>
          <div>
            <p class="eyebrow">Users</p>
            <h1 id="users-title" class="h3" tabindex="-1">Users</h1>
          </div>
        </div>
        <div class="users-header-actions">
          <input
            id="users-search"
            class="input users-search"
            type="search"
            placeholder="Search users"
            aria-label="Search users"
            value={@filter}
            phx-keyup="filter_users"
            phx-debounce="150"
            autocomplete="off"
          />
          <button
            :if={Scope.allowed?(@scope, "user.setting")}
            class="btn"
            type="button"
            data-variant="default"
            phx-click="new_user"
          >
            Create user
          </button>
        </div>
      </header>
      <p class="users-status" role="status">{@status}</p>
      <div class="user-list">
        <article :for={user <- @users} class="card user-card">
          <div class="card-content">
            <div class="user-card-heading">
              <h3 class="card-title">{user_name(user)}</h3>
              <span class={["user-status", active?(user) && "is-active"]}>
                {if active?(user), do: "Active", else: "Inactive"}
              </span>
            </div>
            <dl class="user-meta">
              <div><dt>Username</dt><dd>{user.username}</dd></div>
              <div><dt>User type</dt><dd>Employee</dd></div>
              <div><dt>Stores</dt><dd>{store_names(@options.stores, user.store_ids)}</dd></div>
              <div><dt>Permissions</dt><dd>{permission_names(user.scopes)}</dd></div>
            </dl>
          </div>
          <div class="card-footer">
            <button class="btn" type="button" data-variant="outline" phx-click="view_user" phx-value-id={user.id}>
              View
            </button>
            <button
              :if={Scope.allowed?(@scope, "user.setting")}
              class="btn"
              type="button"
              data-variant="default"
              phx-click="edit_user"
              phx-value-id={user.id}
            >
              Edit
            </button>
            <button
              :if={Scope.allowed?(@scope, "user.setting") and active?(user)}
              class="btn"
              type="button"
              data-variant="destructive"
              phx-click="deactivate_user"
              phx-value-id={user.id}
              phx-confirm={"Deactivate #{user_name(user)}?"}
            >
              Deactivate
            </button>
          </div>
        </article>
      </div>
    </section>
    """
  end

  attr :mode, :atom, required: true
  attr :user, :map, default: nil
  attr :options, :map, required: true
  attr :status, :string, required: true
  attr :saving, :boolean, default: false

  def user_form(assigns) do
    ~H"""
    <section id="users-screen" class="users-screen application-screen" aria-labelledby="users-title">
      <header class="users-header">
        <div>
          <p class="eyebrow">Users</p>
          <h2 id="users-title" class="h3" tabindex="-1">{form_title(@mode)}</h2>
        </div>
      </header>
      <div class="card user-form-card">
        <div class="card-content">
          <form class="form" novalidate phx-submit="save_user">
            <input :if={@user} type="hidden" name="id" value={@user.id} />
            <.text_field name="first_name" label="First name" value={field_value(@user, :first_name)} required disabled={@mode == :view} />
            <.text_field name="last_name" label="Last name" value={field_value(@user, :last_name)} required disabled={@mode == :view} />
            <.text_field name="username" label="Username" value={field_value(@user, :username)} required disabled={@mode == :view} />
            <.text_field
              name="password"
              label={if @user, do: "New password (leave blank to keep current)", else: "Password"}
              type="password"
              value=""
              required={is_nil(@user)}
              disabled={@mode == :view}
            />
            <div class="form-field-inline">
              <input
                id="user-active"
                class="checkbox"
                type="checkbox"
                name="user[is_active]"
                value="1"
                checked={if @user, do: active?(@user), else: true}
                disabled={@mode == :view}
              />
              <label class="label" for="user-active">Active user</label>
            </div>
            <.checkboxes items={@options.stores} selected={selected(@user, :store_ids)} name="store_ids" label="Assigned stores" disabled={@mode == :view} />
            <.checkboxes items={@options.scopes} selected={selected(@user, :scopes)} name="scopes" label="Permissions" disabled={@mode == :view} />
            <p class="field-description" role="status">{@status}</p>
            <div class="form-actions">
              <button class="btn" type="button" data-variant="outline" phx-click="list_users">
                {if @mode == :view, do: "Back", else: "Cancel"}
              </button>
              <button :if={@mode != :view} class="btn" type="submit" data-variant="default" disabled={@saving}>
                Save
              </button>
            </div>
          </form>
        </div>
      </div>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :value, :string, default: ""
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false

  defp text_field(assigns) do
    ~H"""
    <div class="form-field">
      <label class="label" for={"user-#{@name}"}>{@label}</label>
      <input
        class="input"
        name={"user[#{@name}]"}
        id={"user-#{@name}"}
        type={@type}
        required={@required}
        value={@value}
        disabled={@disabled}
      />
    </div>
    """
  end

  attr :items, :list, required: true
  attr :selected, :list, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :disabled, :boolean, default: false

  defp checkboxes(assigns) do
    ~H"""
    <fieldset class="form-fieldset user-assignment">
      <legend>{@label}</legend>
      <div class="form-group">
        <div :for={item <- @items} class="form-field-inline">
          <input
            type="checkbox"
            class="checkbox"
            name={"#{@name}[]"}
            value={item_value(item)}
            id={"#{@name}-#{item_value(item)}"}
            checked={selected?(@selected, item_value(item))}
            disabled={@disabled}
          />
          <label class="label" for={"#{@name}-#{item_value(item)}"}>{item_label(item)}</label>
        </div>
      </div>
    </fieldset>
    """
  end

  defp form_title(:view), do: "Details"
  defp form_title(:edit), do: "Edit"
  defp form_title(:new), do: "Create"

  defp user_name(user) do
    name = Enum.join(Enum.filter([user.first_name, user.last_name], &present?/1), " ")
    if name == "", do: user.username, else: name
  end
  defp active?(user), do: int(user.is_active) == 1
  defp selected(nil, _field), do: []
  defp selected(user, field), do: Map.get(user, field, [])
  defp field_value(nil, _field), do: ""
  defp field_value(user, field), do: Map.get(user, field) || ""
  defp item_value(%{id: id}), do: id
  defp item_value(value), do: value
  defp item_label(%{name: name}), do: name
  defp item_label(value), do: value
  defp selected?(selected, value), do: value in selected or to_string(value) in selected
  defp permission_names([]), do: "No permissions"
  defp permission_names(nil), do: "No permissions"
  defp permission_names(scopes), do: Enum.join(scopes, ", ")
  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp store_names(stores, ids) do
    names =
      (ids || [])
      |> Enum.map(fn id -> Enum.find(stores, &(int(&1.id) == int(id))) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.name)

    if names == [], do: "No stores", else: Enum.join(names, ", ")
  end

  defp int(value) when is_integer(value), do: value
  defp int(value) when is_binary(value), do: value |> Integer.parse() |> parse_int()
  defp int(_), do: nil
  defp parse_int({number, _}), do: number
  defp parse_int(:error), do: nil
end
