defmodule PosServerWeb.LoginLive do
  @moduledoc false
  use PosServerWeb, :live_view

  alias PosServer.{Authentication, TenantContext}
  alias PosServer.Retaily.InventoryContext

  @impl true
  def mount(_params, session, socket) do
    case session["user_token"] && Authentication.authenticate(session["user_token"]) do
      {:ok, _scope} ->
        {:ok, redirect(socket, to: ~p"/pos")}

      _ ->
        {:ok,
         socket
         |> assign(:page_title, "Tigoo Sign in")
         |> assign(:phase, :credentials)
         |> assign(:pending_token, nil)
         |> assign(:stores, [])
         |> assign(:error, "")
         |> assign(:submitting?, false)}
    end
  end

  @impl true
  def handle_event("login", %{"identifier" => identifier, "password" => password}, socket) do
    socket = assign(socket, :error, "")

    case Authentication.login(%{"identifier" => String.trim(identifier), "password" => password}) do
      {:ok, token, scope} ->
        TenantContext.put_tenant(scope.tenant)

        case InventoryContext.stores(scope) do
          {:ok, []} ->
            {:noreply, assign(socket, :error, "No store is available for this account.")}

          {:ok, stores} ->
            {:noreply,
             socket
             |> assign(:phase, :store_selection)
             |> assign(:pending_token, token)
             |> assign(:stores, stores)}

          _ ->
            {:noreply, assign(socket, :error, "Stores could not be loaded.")}
        end

      {:error, :invalid_credentials} ->
        {:noreply, assign(socket, :error, "The username/email or password is incorrect.")}
    end
  end

  def handle_event("select_store", %{"store_id" => store_id}, socket) do
    case {socket.assigns.pending_token, Integer.parse(to_string(store_id))} do
      {token, {id, ""}} when is_binary(token) and id > 0 ->
        if Enum.any?(socket.assigns.stores, &(&1.id == id)) do
          {:noreply,
           socket
           |> assign(:submitting?, true)
           |> push_event("login:complete", %{token: token, store_id: id})}
        else
          {:noreply, assign(socket, :error, "Select a store to continue.")}
        end

      _ ->
        {:noreply, assign(socket, :error, "Select a store to continue.")}
    end
  end

  def handle_event("google_unavailable", _, socket),
    do:
      {:noreply,
       assign(socket, :error, "Google sign-in is available in the desktop or mobile app.")}

  def handle_event("session_failed", _, socket),
    do: {:noreply, socket |> assign(:submitting?, false) |> assign(:error, "Unable to sign in.")}

  @impl true
  def render(assigns) do
    ~H"""
    <section
      id="login-screen"
      class="login-screen"
      aria-labelledby="login-title"
      phx-hook="LoginScreen"
      data-phase={@phase}
    >
      <.login_effects />
      <div class="login-panel">
        <div class="card login-card">
          <div class="card-header">
            <h1 id="login-title" class="card-title" data-i18n="pos.login.signIn">Sign in</h1>
            <p class="card-description" data-i18n="pos.login.copy">Use your username or email and password to continue.</p>
          </div>
          <div class="card-content">
            <form
              id="login-form"
              class="form"
              novalidate
              phx-submit={if @phase == :credentials, do: "login", else: "select_store"}
            >
              <.login_error error={@error} />
              <div class="form-field">
                <label class="label" for="login-identifier" data-i18n="pos.login.usernameOrEmail">Username or email</label>
                <input
                  id="login-identifier"
                  class="input"
                  name="identifier"
                  autocomplete="username"
                  required
                  autofocus
                  disabled={@phase == :store_selection}
                />
              </div>
              <div class="form-field">
                <label class="label" for="login-password" data-i18n="pos.login.password">Password</label>
                <input
                  id="login-password"
                  class="input"
                  name="password"
                  type="password"
                  autocomplete="current-password"
                  required
                  disabled={@phase == :store_selection}
                />
              </div>
              <div :if={@phase == :store_selection} id="login-store-field" class="form-field">
                <label class="label" for="login-store" data-i18n="pos.login.store">Store</label><select
                  id="login-store"
                  class="select"
                  name="store_id"
                  required
                ><option value="" disabled selected data-i18n="pos.login.selectStore">Select a store</option><option
                  :for={store <- @stores}
                  value={store.id}
                >{store.name}</option></select>
              </div>
              <div class="form-actions">
                <button
                  id="login-submit"
                  class="btn login-submit"
                  type="submit"
                  data-variant="default"
                  disabled={@submitting?}
                >
                  <span data-i18n={if @phase == :store_selection, do: "common.continue", else: "pos.login.signIn"}>{if @phase == :store_selection, do: "Continue", else: "Sign in"}</span>
                </button><button
                  id="google-login"
                  class="btn login-submit"
                  type="button"
                  data-variant="outline"
                  disabled={@phase == :store_selection or @submitting?}
                  phx-click="google_unavailable"
                ><span data-i18n="pos.login.continueWithGoogle">Continue with Google</span></button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp login_effects(assigns) do
    ~H"""
    <div class="login-effects" aria-hidden="true">
      <i class="login-travel-layer login-travel-layer-far"></i><i class="login-travel-layer login-travel-layer-mid"></i><i class="login-travel-layer login-travel-layer-near"></i><i class="login-travel-flyby"></i>
    </div>
    """
  end

  attr :error, :string, required: true

  defp login_error(assigns) do
    ~H"""
    <div
      id="login-error"
      class="alert login-error"
      data-variant="destructive"
      role="alert"
      hidden={@error == ""}
    >
      <div class="alert-content">
        <p id="login-error-message" class="alert-description">{@error}</p>
      </div>
    </div>
    """
  end
end
