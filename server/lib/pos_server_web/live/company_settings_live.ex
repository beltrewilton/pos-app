defmodule PosServerWeb.CompanySettingsLive do
  @moduledoc false
  use PosServerWeb, :live_view

  alias PosServer.{Authentication, TenantContext}
  alias PosServer.Accounts.Scope
  alias PosServer.Retaily.CompanySettings

  @kinds ~w(price-list store provider sequence)

  @impl true
  def mount(_params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, scope} <- Authentication.authenticate(token),
         true <- Scope.allowed?(scope, "company.settings"),
         _ <- TenantContext.put_tenant(scope.tenant),
         {:ok, overview} <- CompanySettings.overview(scope) do
      {:ok,
       socket
       |> assign(:page_title, "Tigoo Company settings")
       |> assign(:scope, scope)
       |> assign(:overview, overview)
       |> assign(:editing, nil)
       |> assign(:status, "")}
    else
      _ -> {:ok, socket |> put_flash(:error, "Company settings access is required.") |> redirect(to: ~p"/pos")}
    end
  end

  @impl true
  def handle_event("add", %{"kind" => kind}, socket) when kind in @kinds,
    do: {:noreply, assign(socket, :editing, {kind, :new})}

  def handle_event("edit", %{"kind" => kind, "id" => id}, socket) when kind in @kinds do
    with {id, ""} <- Integer.parse(id), true <- entry(socket.assigns.overview, kind, id) do
      {:noreply, assign(socket, :editing, {kind, id})}
    else
      _ -> {:noreply, assign(socket, :status, "This item could not be found.")}
    end
  end

  def handle_event("cancel", _, socket), do: {:noreply, socket |> assign(:editing, nil) |> assign(:status, "")}

  def handle_event("save", %{"kind" => kind} = params, socket) when kind in @kinds do
    result =
      case {kind, socket.assigns.editing} do
        {"price-list", {"price-list", :new}} -> CompanySettings.create_price_list(socket.assigns.scope, %{"label" => Map.get(params, "name", "")})
        {"price-list", {"price-list", id}} -> CompanySettings.update_price_list(socket.assigns.scope, id, %{"label" => Map.get(params, "name", "")})
        {"store", {"store", :new}} -> CompanySettings.create_store(socket.assigns.scope, store_attrs(params))
        {"store", {"store", id}} -> CompanySettings.update_store(socket.assigns.scope, id, store_attrs(params))
        {"provider", {"provider", :new}} -> CompanySettings.create_provider(socket.assigns.scope, %{"name" => Map.get(params, "name", "")})
        {"provider", {"provider", id}} -> CompanySettings.update_provider(socket.assigns.scope, id, %{"name" => Map.get(params, "name", "")})
        {"sequence", {"sequence", :new}} -> CompanySettings.create_sequence_set(socket.assigns.scope, sequence_attrs(params))
        {"sequence", {"sequence", id}} -> CompanySettings.update_sequence_set(socket.assigns.scope, id, sequence_attrs(params))
        _ -> {:error, :invalid_edit}
      end

    case result do
      {:ok, _} -> {:noreply, socket |> assign(:editing, nil) |> assign(:status, "") |> reload()}
      {:error, reason} -> {:noreply, assign(socket, :status, error_message(reason, kind, :save))}
    end
  end

  def handle_event("delete", %{"kind" => kind, "id" => id}, socket) when kind in ["price-list", "provider", "sequence"] do
    with {id, ""} <- Integer.parse(id) do
      result = case kind do
        "price-list" -> CompanySettings.delete_price_list(id)
        "provider" -> CompanySettings.delete_provider(id)
        "sequence" -> CompanySettings.delete_sequence_set(id)
      end

      case result do
        {:ok, _} -> {:noreply, socket |> assign(:editing, nil) |> assign(:status, "") |> reload()}
        {:error, reason} -> {:noreply, assign(socket, :status, error_message(reason, kind, :delete))}
      end
    else
      _ -> {:noreply, assign(socket, :status, "This item could not be found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="company-settings-live" class="pos-shell invoice-view" phx-hook="CompanySettings" data-editing={editing_key(@editing)}>
      <svg class="navigation-icon-sprite" aria-hidden="true" focusable="false"><symbol id="nav-icon-pos" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3h18v18H3z"/><path d="M7 7h10v10H7z"/></symbol><symbol id="nav-icon-sales" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 2v20h16"/><path d="M8 6h8M8 10h8M8 14h5"/></symbol><symbol id="nav-icon-inventory" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 7 9-4 9 4-9 4-9-4Z"/><path d="m3 12 9 4 9-4M3 17l9 4 9-4"/></symbol><symbol id="nav-icon-orders" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h9l3 3v17H6z"/><path d="M15 2v4h4M9 12h6M9 16h6"/></symbol><symbol id="nav-icon-company" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 9 2-5h14l2 5"/><path d="M3 9h18v11H3z"/><path d="M7 20v-6h4v6"/><path d="M3 9c0 2 2 3 4 3s4-1 4-3c0 2 2 3 4 3s4-1 4-3"/></symbol></svg>
      <nav class="sidebar-rail" aria-label="Primary navigation">
        <a id="pos-nav" class="sidebar-link" href={~p"/pos"} aria-label="POS"><svg aria-hidden="true"><use href="#nav-icon-pos"/></svg></a>
        <a id="sales-report-nav" class="sidebar-link" href={~p"/pos/invoices"} aria-label="Invoice report"><svg aria-hidden="true"><use href="#nav-icon-sales"/></svg></a>
        <a id="inventory-nav" class="sidebar-link" href={~p"/pos/inventory"} aria-label="Inventory"><svg aria-hidden="true"><use href="#nav-icon-inventory"/></svg></a>
        <a id="orders-nav" class="sidebar-link" href={~p"/pos/orders"} aria-label="Purchase orders"><svg aria-hidden="true"><use href="#nav-icon-orders"/></svg></a>
        <a id="company-settings-nav" class="sidebar-link" href={~p"/pos/company-settings"} aria-current="page" aria-label="Company settings"><svg aria-hidden="true"><use href="#nav-icon-company"/></svg></a>
      </nav>
      <section class="catalog-panel" data-view="company-settings" aria-labelledby="company-settings-title">
        <section id="company-settings-screen" class="company-settings-screen" aria-labelledby="company-settings-title">
          <div class="company-settings-fixed">
            <header class="topbar company-settings-topbar"><div class="brand-lockup"><span class="brand-mark" aria-hidden="true">E</span><div><p class="eyebrow">Company</p><h2 id="company-settings-title" tabindex="-1">Company settings</h2></div></div></header>
            <article class="card company-summary" aria-labelledby="company-summary-title"><div class="card-header"><h3 id="company-summary-title" class="card-title">Current company</h3><p id="company-settings-company" class="card-description">{company_name(@overview.company)}</p></div></article>
            <p id="company-settings-status" class="company-settings-status" role="status">{@status}</p>
          </div>
          <div class="company-settings-cards">
            <.settings_card kind="price-list" title="Price lists" description="Manage the labels used for product prices." add_label="Add price list" entries={@overview.price_lists} editing={@editing} empty="No price lists yet." company={@overview.company}/>
            <.settings_card kind="store" title="Stores" description="Manage your company’s store locations." add_label="Add store" entries={@overview.stores} editing={@editing} empty="No stores yet." company={@overview.company}/>
            <.settings_card kind="sequence" title="Sequence sets" description="Set the invoice sequences used for CF, VF, and DV sales." add_label="Add sequence" entries={@overview.sequence_sets} editing={@editing} empty="No sequences configured. Add CF, VF, and DV to complete sales." company={@overview.company}/>
            <.settings_card kind="provider" title="Providers" description="Manage the providers used for purchase orders." add_label="Add provider" entries={@overview.providers} editing={@editing} empty="No providers yet." company={@overview.company}/>
          </div>
        </section>
      </section>
    </main>
    """
  end

  attr :kind, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :add_label, :string, required: true
  attr :entries, :list, required: true
  attr :editing, :any, required: true
  attr :empty, :string, required: true
  attr :company, :map, required: true
  defp settings_card(assigns) do
    ~H"""
    <article class="card company-settings-card" aria-labelledby={title_id(@kind)}>
      <div class="card-header company-settings-card-header"><div><h3 id={title_id(@kind)} class="card-title">{@title}</h3><p class="card-description">{@description}</p></div><button id={add_id(@kind)} class="btn" type="button" data-variant="default" data-size="sm" phx-click="add" phx-value-kind={@kind}>{@add_label}</button></div>
      <div id={content_id(@kind)} class="card-content">
        <.setting_form :if={@editing == {@kind, :new}} kind={@kind} entry={nil} company={@company}/>
        <%= for entry <- @entries do %>
          <.setting_form :if={@editing == {@kind, entry.id}} kind={@kind} entry={entry} company={@company}/>
          <.setting_row :if={@editing != {@kind, entry.id}} kind={@kind} entry={entry}/>
        <% end %>
        <p :if={@entries == [] and @editing != {@kind, :new}} class="field-description company-settings-empty">{@empty}</p>
      </div>
    </article>
    """
  end

  attr :kind, :string, required: true
  attr :entry, :any, required: true
  attr :company, :map, required: true
  defp setting_form(assigns) do
    ~H"""
    <form class="form company-setting-form" phx-submit="save" phx-value-kind={@kind}>
      <input type="hidden" name="kind" value={@kind}/>
      <%= if @kind == "sequence" do %>
        <.field label="Name" name="name" value={value(@entry, :name)} required/><.field label="Code" name="code" value={value(@entry, :code)} required/><.field label="Prefix" name="prefix" value={value(@entry, :prefix)} required/><.field label="Digits" name="fill" value={value(@entry, :fill) || 8} type="number" required/><.field label="Increment" name="increment_by" value={value(@entry, :increment_by) || 1} type="number" required/><.field label="Next number" name="current_seq" value={value(@entry, :current_seq) || 0} type="number" required/>
      <% else %>
        <.field label={setting_name_label(@kind)} name="name" value={value(@entry, setting_name_key(@kind))} required/>
        <%= if @kind == "store" do %>
          <p class="field-description store-company-context">Company: {value(@company, :name) || "Current company"}</p><.field label="Slogan" name="slogan" value={value(@entry, :slogan)}/><.field label="Address" name="address" value={value(@entry, :address)} multiline/>
          <div id={"store-logo-field-#{value(@entry, :id) || "new"}"} class="form-field store-logo-field" phx-update="ignore"><div class="product-image-dropzone store-logo-dropzone" tabindex="0" role="button"><img class="product-image-preview store-logo-preview" src={value(@entry, :logo)} alt="Store logo preview" hidden={is_nil(value(@entry, :logo))}/><label class="label">Store logo</label><p class="field-description">Drop an image here or choose a file (max 10 MB). It will be resized and stored as Base64.</p><input class="input" type="file" accept="image/*"/></div><input class="store-logo-value" type="hidden" name="logo" value={value(@entry, :logo)}/><button :if={value(@entry, :logo)} class="btn store-logo-remove" type="button" data-variant="outline" data-remove-store-logo>Remove logo</button></div>
        <% end %>
      <% end %>
      <div class="form-actions"><button class="btn" type="button" data-variant="outline" phx-click="cancel">Cancel</button><button class="btn" type="submit" data-variant="default">{submit_label(@kind, @entry)}</button></div>
    </form>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :required, :boolean, default: false
  attr :multiline, :boolean, default: false
  defp field(assigns) do
    ~H"""
    <div class="form-field"><label class="label" for={"company-setting-#{@name}"}>{@label}</label><textarea :if={@multiline} id={"company-setting-#{@name}"} class="input" name={@name}>{@value}</textarea><input :if={!@multiline} id={"company-setting-#{@name}"} class="input" name={@name} type={@type} value={@value} required={@required}/></div>
    """
  end

  attr :kind, :string, required: true
  attr :entry, :map, required: true
  defp setting_row(assigns) do
    ~H"""
    <div class="company-setting-row"><div><img :if={@kind == "store" and value(@entry, :logo)} class="store-logo-thumbnail" src={value(@entry, :logo)} alt=""/><strong>{row_title(@kind, @entry)}</strong><p class="field-description">{row_description(@kind, @entry)}</p></div><div class="company-setting-actions"><button class="btn" type="button" data-variant="outline" data-size="sm" phx-click="edit" phx-value-kind={@kind} phx-value-id={@entry.id}>Edit</button><button :if={@kind != "store"} class="btn" type="button" data-variant="destructive" data-size="sm" data-company-settings-confirm={delete_message(@kind)} data-delete-kind={@kind} data-delete-id={@entry.id}>Delete</button></div></div>
    """
  end

  defp reload(socket) do
    case CompanySettings.overview(socket.assigns.scope) do
      {:ok, overview} -> assign(socket, :overview, overview)
      _ -> assign(socket, :status, "Company settings could not be loaded.")
    end
  end

  defp store_attrs(params), do: Map.take(params, ["name", "slogan", "address", "logo"])
  defp sequence_attrs(params) do
    numeric_values =
      Enum.into(~w(fill increment_by current_seq), %{}, fn key ->
        {key, integer(Map.get(params, key))}
      end)

    Map.take(params, ["name", "code", "prefix"]) |> Map.merge(numeric_values)
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) do
    case Integer.parse(to_string(value || "")) do
      {number, ""} -> number
      _ -> 0
    end
  end
  defp entry(overview, "price-list", id), do: Enum.find(overview.price_lists, &(&1.id == id))
  defp entry(overview, "store", id), do: Enum.find(overview.stores, &(&1.id == id))
  defp entry(overview, "provider", id), do: Enum.find(overview.providers, &(&1.id == id))
  defp entry(overview, "sequence", id), do: Enum.find(overview.sequence_sets, &(&1.id == id))
  defp value(nil, _key), do: nil
  defp value(entry, key), do: Map.get(entry, key) || Map.get(entry, Atom.to_string(key))
  defp company_name(company), do: [value(company, :name), if(value(company, :rnc), do: "RNC #{value(company, :rnc)}")] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")
  defp editing_key(nil), do: ""
  defp editing_key({kind, id}), do: "#{kind}:#{id}"
  defp title_id("price-list"), do: "price-lists-title"
  defp title_id("store"), do: "stores-title"
  defp title_id("sequence"), do: "sequence-sets-title"
  defp title_id("provider"), do: "providers-title"
  defp add_id("price-list"), do: "add-price-list"
  defp add_id("store"), do: "add-store"
  defp add_id("sequence"), do: "add-sequence-set"
  defp add_id("provider"), do: "add-provider"
  defp content_id("price-list"), do: "price-lists-content"
  defp content_id("store"), do: "stores-content"
  defp content_id("sequence"), do: "sequence-sets-content"
  defp content_id("provider"), do: "providers-content"
  defp setting_name_label("price-list"), do: "Price list label"
  defp setting_name_label("provider"), do: "Provider name"
  defp setting_name_label(_), do: "Store name"
  defp setting_name_key("price-list"), do: :label
  defp setting_name_key(_), do: :name
  defp submit_label(_kind, entry) when not is_nil(entry), do: "Save"
  defp submit_label("sequence", nil), do: "Save"
  defp submit_label(_, nil), do: "Create"
  defp row_title("sequence", entry), do: "#{value(entry, :code)} · #{value(entry, :name)}"
  defp row_title("price-list", entry), do: value(entry, :label)
  defp row_title(_, entry), do: value(entry, :name)
  defp row_description("store", entry) do
    case [value(entry, :slogan), value(entry, :address)] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" · ") do
      "" -> "No store details provided"
      text -> text
    end
  end
  defp row_description("sequence", entry), do: "#{value(entry, :prefix)}#{String.pad_leading(to_string(value(entry, :current_seq)), value(entry, :fill), "0")} · increments by #{value(entry, :increment_by)}"
  defp row_description("price-list", entry), do: value(entry, :price_key) || ""
  defp row_description(_, _), do: ""
  defp delete_message("price-list"), do: "Delete this price list?"
  defp delete_message("sequence"), do: "Delete this sequence set?"
  defp delete_message(kind), do: "Delete this #{kind}?"
  defp error_message(_reason, "price-list", :save), do: "Could not save price list."
  defp error_message(_reason, "store", :save), do: "Could not save store."
  defp error_message(_reason, "provider", :save), do: "Could not save provider."
  defp error_message(_reason, "sequence", :save), do: "Could not save sequence set."
  defp error_message(_reason, "price-list", :delete), do: "Could not delete price list."
  defp error_message(_reason, "provider", :delete), do: "Could not delete provider."
  defp error_message(_reason, "sequence", :delete), do: "Could not delete sequence set."
end
