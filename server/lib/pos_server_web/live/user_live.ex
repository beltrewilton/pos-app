defmodule PosServerWeb.UserLive do
  use PosServerWeb, :live_view
  alias PosServer.Accounts
  alias PosServer.Accounts.User

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket |> assign(:users, Accounts.list_users()) |> assign_user_form(Accounts.change_user(%User{})) |> assign_company_form(Accounts.change_company(%PosServer.Accounts.Company{}))}

  @impl true
  def handle_event("save_user", %{"user" => user_attrs, "company" => company_attrs}, socket) do
    case Accounts.create_company_user(user_attrs, company_attrs) do
      {:ok, user} -> {:noreply, socket |> put_flash(:info, "#{user.name} and their company workspace have been created.") |> push_navigate(to: ~p"/users")}
      {:error, :user, changeset} -> {:noreply, assign_user_form(socket, changeset)}
      {:error, :company, changeset} -> {:noreply, assign_company_form(socket, changeset)}
      {:error, :tenant, reason} ->
        IO.inspect(reason, label: "Tenant workspace creation failed")
        {:noreply, put_flash(socket, :error, "The tenant workspace could not be created. Please try again.")}
    end
  end

  @impl true
  def render(assigns), do: if(assigns.live_action == :new, do: form_page(assigns), else: index_page(assigns))

  defp index_page(assigns) do
    ~H"""
    <main class="admin-page" aria-labelledby="users-title"><header class="admin-topbar"><a class="brand" href={~p"/"}><span class="brand-mark" aria-hidden="true">R</span><span>retaily</span></a><div class="admin-topbar-actions"><button class="btn" data-variant="ghost" data-size="icon" type="button" data-theme-toggle aria-label="Toggle color theme"><span aria-hidden="true">◐</span></button><a class="btn" data-variant="ghost" href={~p"/"}>Overview</a><a class="btn" data-variant="default" href={~p"/users/new"}>Create user <span aria-hidden="true">+</span></a></div></header><section class="admin-content"><div class="admin-heading"><div><p class="eyebrow"><span aria-hidden="true"></span> Team administration</p><h1 id="users-title">Users</h1><p>Manage the people and company workspaces in Retaily.</p></div><a class="btn admin-create-inline" data-variant="default" href={~p"/users/new"}>Create user <span aria-hidden="true">+</span></a></div><div class="list-toolbar" role="search"><label class="sr-only" for="user-search">Search users</label><span aria-hidden="true">⌕</span><input class="input" id="user-search" type="search" placeholder="Search by name, email, or workspace" data-user-search autocomplete="off" /></div><section class="card users-card" aria-labelledby="directory-title"><div class="card-header users-card-header"><div><h2 class="card-title" id="directory-title">User directory</h2><p class="card-description"><%= length(@users) %> provisioned <%= if length(@users) == 1, do: "user", else: "users" %></p></div><span class="directory-live" role="status"><i></i> System ready</span></div><div class="table-container"><table class="table" id="users-table"><caption class="sr-only">Provisioned Retaily users and their workspaces.</caption><thead><tr class="table-row"><th class="table-head" scope="col">User</th><th class="table-head" scope="col">Workspace</th><th class="table-head" scope="col">Status</th><th class="table-head" scope="col"><span class="sr-only">Actions</span></th></tr></thead><tbody><tr :if={@users == []} class="table-row"><td class="table-cell users-empty" colspan="4"><strong>Your team is ready for its first member.</strong><span>Create a user to set up their company workspace.</span><a class="btn" data-variant="outline" data-size="sm" href={~p"/users/new"}>Create user</a></td></tr><tr :for={user <- @users} class="table-row" data-user-row data-search={String.downcase("#{user.name} #{user.email} #{user.tenant}")}><td class="table-cell"><div class="user-identity"><span class="user-avatar"><%= initials(user.name) %></span><span><strong><%= user.name %></strong><small><%= user.email %></small></span></div></td><td class="table-cell"><span class="workspace-name"><%= user.tenant %></span><small class="mobile-only"><%= user.email %></small></td><td class="table-cell"><span class="status-badge"><i></i> Provisioned</span></td><td class="table-cell users-actions"><a class="btn" data-variant="ghost" data-size="sm" href={~p"/users/new"} aria-label={"View #{user.name}"}>View <span aria-hidden="true">→</span></a></td></tr></tbody></table></div></section></section></main>
    """
  end

  defp form_page(assigns) do
    ~H"""
    <main class="admin-page" aria-labelledby="new-user-title"><header class="admin-topbar"><a class="brand" href={~p"/"}><span class="brand-mark" aria-hidden="true">R</span><span>retaily</span></a><div class="admin-topbar-actions"><button class="btn" data-variant="ghost" data-size="icon" type="button" data-theme-toggle aria-label="Toggle color theme"><span aria-hidden="true">◐</span></button><a class="btn" data-variant="ghost" href={~p"/users"}>← Back to users</a></div></header><section class="admin-content form-page-content"><div class="admin-heading"><div><p class="eyebrow"><span aria-hidden="true"></span> Team administration</p><h1 id="new-user-title">Create user</h1><p>Add a user and establish the company workspace they will belong to.</p></div></div><form class="card user-form" phx-submit="save_user"><div class="card-content"><fieldset class="form-fieldset"><legend>Person</legend><p class="field-description">The account owner for this workspace.</p><div class="form-grid"><.field field={@user_form[:name]} label="Full name" type="text" required /><.field field={@user_form[:email]} label="Email address" type="email" required /><.field field={@user_form[:password]} label="Temporary password" type="password" required description="At least 12 characters. The user can change it after setup." /></div></fieldset><fieldset class="form-fieldset"><legend>Company workspace</legend><p class="field-description">A workspace groups a company’s stores, users, and permission scopes.</p><div class="form-grid"><.field field={@company_form[:company_name]} label="Company name" type="text" required /><.field field={@company_form[:rnc]} label="RNC" type="text" /><.field field={@user_form[:tenant]} label="Workspace ID" type="text" required description="Lowercase letters, numbers, and underscores only (for example, acme_store)." /></div></fieldset></div><div class="card-footer form-actions"><a class="btn" data-variant="outline" href={~p"/users"}>Cancel</a><button class="btn" data-variant="default" type="submit">Save user <span aria-hidden="true">→</span></button></div></form></section></main>
    """
  end

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :type, :string, required: true
  attr :required, :boolean, default: false
  attr :description, :string, default: nil
  defp field(assigns) do
    ~H"""
    <div class="form-field" data-invalid={@field.errors != [] || nil}>
      <label class="label" for={@field.id}><%= @label %></label>
      <input class="input" id={@field.id} name={@field.name} type={@type} value={if @type == "password", do: nil, else: @field.value} required={@required} autocomplete={if @type == "password", do: "new-password"} aria-invalid={if @field.errors == [], do: "false", else: "true"} />
      <p :if={@description} class="field-description"><%= @description %></p>
      <p :for={{message, _} <- @field.errors} class="field-error" role="alert"><%= message %></p>
    </div>
    """
  end
  defp initials(name), do: name |> String.split(~r/\s+/, trim: true) |> Enum.take(2) |> Enum.map_join("", &String.first/1) |> String.upcase()
  defp assign_user_form(socket, changeset), do: assign(socket, :user_form, to_form(changeset, as: :user))
  defp assign_company_form(socket, changeset), do: assign(socket, :company_form, to_form(changeset, as: :company))
end
