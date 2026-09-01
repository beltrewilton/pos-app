const invoke = window.__TAURI__?.core?.invoke;
if (typeof invoke !== "function") throw new Error("This POS client must run inside Tauri.");

const phoenixServerDns = await invoke("phoenix_server_dns");
const phoenixServerUrl = new URL(phoenixServerDns);
if (!/^https?:$/.test(phoenixServerUrl.protocol)) throw new Error("PHOENIX_SERVER_DNS must be an HTTP(S) URL.");

export const API_BASE_URL = new URL("/api", phoenixServerUrl).toString().replace(/\/$/, "");
const rawFetch = window.fetch.bind(window);

const SESSION_KEY = "retaily-pos-session";

export function session() {
  try { return JSON.parse(sessionStorage.getItem(SESSION_KEY) || localStorage.getItem(SESSION_KEY) || "null"); } catch { return null; }
}

export function saveSession(value, persistent = true) {
  const storage = persistent ? localStorage : sessionStorage;
  storage.setItem(SESSION_KEY, JSON.stringify(value));
  (persistent ? sessionStorage : localStorage).removeItem(SESSION_KEY);
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
  sessionStorage.removeItem(SESSION_KEY);
}

async function apiFetch(url, options = {}) {
  const current = session();
  const headers = new Headers(options.headers || {});
  if (current?.token) headers.set("Authorization", `Bearer ${current.token}`);
  const response = await rawFetch(url, { ...options, headers });
  if (response.status === 401 || response.status === 403) {
    const error = new Error(response.status === 403 ? "You do not have access to this action." : "Your session has expired. Please sign in again.");
    error.status = response.status;
    throw error;
  }
  return response;
}

export async function login(identifier, password) {
  let response;
  try {
    response = await fetch(`${API_BASE_URL}/login`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ identifier, password }) });
  } catch (cause) {
    const error = new Error("Could not connect to the server.");
    error.code = "SERVER_UNAVAILABLE";
    error.cause = cause;
    throw error;
  }
  if (!response.ok) {
    const error = new Error(response.status === 401 ? "The username/email or password is incorrect." : "Unable to sign in.");
    error.status = response.status;
    throw error;
  }
  return response.json();
}

export function tauriGoogleAuthorizationUrl(platform, attemptId) {
  const origin = new URL(API_BASE_URL).origin;
  const url = new URL("/auth/google/tauri", origin);
  url.searchParams.set("platform", platform);
  url.searchParams.set("attempt_id", attemptId);
  return url.toString();
}

export async function createTauriGoogleAttempt(platform) {
  const response = await rawFetch(`${API_BASE_URL}/auth/tauri/attempts`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ platform }),
  });
  if (!response.ok) throw new Error("Could not start Google sign-in.");
  return response.json();
}

export async function exchangeTauriGoogleCode(code) {
  const response = await rawFetch(`${API_BASE_URL}/auth/tauri/exchange`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code }),
  });
  if (!response.ok) throw new Error("Google sign-in could not be completed.");
  return response.json();
}

export async function users() {
  const response = await apiFetch(`${API_BASE_URL}/users`);
  if (!response.ok) throw new Error(`Could not load users: ${response.status}`);
  return response.json();
}
export async function user(userId) {
  const response = await apiFetch(`${API_BASE_URL}/users/${userId}`);
  if (!response.ok) throw new Error(`Could not load user: ${response.status}`);
  return response.json();
}
export async function createUser(attrs) {
  const response = await apiFetch(`${API_BASE_URL}/users`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error(`Could not save user: ${response.status}`);
  return response.json();
}
export async function updateUser(userId, attrs) {
  const response = await apiFetch(`${API_BASE_URL}/users/${userId}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error(`Could not save user: ${response.status}`);
  return response.json();
}
export async function deactivateUser(userId) {
  const response = await apiFetch(`${API_BASE_URL}/users/${userId}`, { method: "DELETE" });
  if (!response.ok) throw new Error(`Could not deactivate user: ${response.status}`);
  return response.json();
}
export async function userOptions() {
  const response = await apiFetch(`${API_BASE_URL}/users/options`);
  if (!response.ok) throw new Error(`Could not load assignment options: ${response.status}`);
  return response.json();
}

// Existing POS calls share this authenticated transport. Login remains public.
window.fetch = (url, options = {}) => {
  if (String(url).endsWith("/login")) return rawFetch(url, options);
  const current = session();
  const headers = new Headers(options.headers || {});
  if (current?.token) headers.set("Authorization", `Bearer ${current.token}`);
  return rawFetch(url, { ...options, headers });
};

export async function health() {
  const response = await fetch(`${API_BASE_URL}/health`);
  if (!response.ok) throw new Error(`Server health check failed: ${response.status}`);
  return response.json();
}

export async function activeProducts(storeId, cursor = null, search = "") {
  const url = new URL(`${API_BASE_URL}/products`);
  url.searchParams.set("store_id", storeId);
  if (cursor !== null) url.searchParams.set("cursor", cursor);
  if (search.trim()) url.searchParams.set("search", search.trim());

  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load products: ${response.status}`);
  return response.json();
}

export async function createProduct(product) {
  const response = await fetch(`${API_BASE_URL}/products`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(product) });
  if (!response.ok) throw new Error(`Could not create product: ${response.status}`);
  return response.json();
}
export async function product(productId) {
  const response = await fetch(`${API_BASE_URL}/products/${productId}`);
  if (!response.ok) throw new Error(`Could not load product: ${response.status}`);
  return response.json();
}
export async function updateProduct(productId, attrs) {
  const response = await fetch(`${API_BASE_URL}/products/${productId}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error(`Could not update product: ${response.status}`);
  return response.json();
}
export async function pricingLists() {
  const response = await fetch(`${API_BASE_URL}/pricing-lists`);
  if (!response.ok) throw new Error(`Could not load pricing lists: ${response.status}`);
  return response.json();
}
export async function stores() {
  const response = await apiFetch(`${API_BASE_URL}/stores`);
  if (!response.ok) throw new Error(`Could not load stores: ${response.status}`);
  return response.json();
}
export async function companySettings() {
  const response = await apiFetch(`${API_BASE_URL}/company-settings`);
  if (!response.ok) throw new Error(`Could not load company settings: ${response.status}`);
  return response.json();
}
export async function createPriceList(attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/price-lists`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save price list.");
  return response.json();
}
export async function updatePriceList(id, attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/price-lists/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save price list.");
  return response.json();
}
export async function deletePriceList(id) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/price-lists/${id}`, { method: "DELETE" });
  if (!response.ok) throw new Error("Could not delete price list.");
  return response.json();
}
export async function createStore(attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/stores`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save store.");
  return response.json();
}
export async function updateStore(id, attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/stores/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save store.");
  return response.json();
}
export async function deleteStore(id) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/stores/${id}`, { method: "DELETE" });
  if (!response.ok) throw new Error("Could not delete store.");
  return response.json();
}
export async function createSequenceSet(attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/sequences`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save sequence set.");
  return response.json();
}
export async function updateSequenceSet(id, attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/sequences/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save sequence set.");
  return response.json();
}
export async function deleteSequenceSet(id) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/sequences/${id}`, { method: "DELETE" });
  if (!response.ok) throw new Error("Could not delete sequence set.");
  return response.json();
}
export async function createProvider(attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/providers`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save provider.");
  return response.json();
}
export async function updateProvider(id, attrs) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/providers/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(attrs) });
  if (!response.ok) throw new Error("Could not save provider.");
  return response.json();
}
export async function deleteProvider(id) {
  const response = await apiFetch(`${API_BASE_URL}/company-settings/providers/${id}`, { method: "DELETE" });
  if (!response.ok) throw new Error("Could not delete provider.");
  return response.json();
}
export async function setProductPrices(productId, prices) {
  const response = await fetch(`${API_BASE_URL}/products/${productId}/prices`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ prices }) });
  if (!response.ok) throw new Error(`Could not save product prices: ${response.status}`);
  return response.json();
}

export async function inventoryQuantities(storeId, productIds) {
  const url = new URL(`${API_BASE_URL}/inventory`);
  url.searchParams.set("store_id", storeId);
  url.searchParams.set("product_ids", productIds.join(","));
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not refresh inventory: ${response.status}`);
  return response.json();
}

export async function inventoryStoreQuantities(storeId, productId) {
  const url = new URL(`${API_BASE_URL}/inventory`);
  url.searchParams.set("store_id", storeId);
  url.searchParams.set("product_ids", productId);
  url.searchParams.set("all_stores", "true");
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load store quantities: ${response.status}`);
  return response.json();
}

export async function inventorySummary(storeId) {
  const url = new URL(`${API_BASE_URL}/inventory/summary`);
  url.searchParams.set("store_id", storeId);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load inventory summary: ${response.status}`);
  return response.json();
}

export async function productTraces(storeId, productId) {
  const url = new URL(`${API_BASE_URL}/inventory/${productId}/traces`);
  url.searchParams.set("store_id", storeId);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load product history: ${response.status}`);
  return response.json();
}

export async function adjustInventory(adjustment) {
  const response = await fetch(`${API_BASE_URL}/inventory/adjustments`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(adjustment) });
  if (!response.ok) throw new Error(`Could not update inventory: ${response.status}`);
  return response.json();
}

export async function moveInventory(move) {
  const response = await fetch(`${API_BASE_URL}/inventory/moves`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(move) });
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload.error || "Could not move products.");
  }
  return response.json();
}

export async function productOrders(storeId, status = "") {
  const url = new URL(`${API_BASE_URL}/product-orders`); url.searchParams.set("store_id", storeId);
  if (status) url.searchParams.set("status", status);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load purchase orders: ${response.status}`);
  return response.json();
}

export async function purchaseSources(storeId) {
  const url = new URL(`${API_BASE_URL}/purchase-sources`);
  url.searchParams.set("store_id", storeId);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load purchase sources: ${response.status}`);
  return response.json();
}

export async function createProductOrder(order) {
  const response = await fetch(`${API_BASE_URL}/product-orders`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(order) });
  if (!response.ok) throw new Error(`Could not create purchase order: ${response.status}`);
  return response.json();
}

export async function receiveProductOrder(id, receipt) {
  const response = await fetch(`${API_BASE_URL}/product-orders/${id}/receive`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(receipt) });
  if (!response.ok) throw new Error(`Could not process purchase order: ${response.status}`);
  return response.json();
}

export async function customers(search = "") {
  const url = new URL(`${API_BASE_URL}/customers`);
  if (search) url.searchParams.set("search", search);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load customers: ${response.status}`);
  return response.json();
}

export async function createCustomer(customer) {
  const response = await fetch(`${API_BASE_URL}/customers`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(customer),
  });
  if (!response.ok) throw new Error(`Could not create customer: ${response.status}`);
  return response.json();
}

export async function customerPurchases(customerId) {
  const response = await fetch(`${API_BASE_URL}/customers/${customerId}/purchases`);
  if (!response.ok) throw new Error(`Could not load customer purchases: ${response.status}`);
  return response.json();
}

export async function customerDetail(customerId) {
  const response = await fetch(`${API_BASE_URL}/customers/${customerId}`);
  if (!response.ok) throw new Error(`Could not load customer details: ${response.status}`);
  return response.json();
}

export async function createSale(sale) {
  const response = await fetch(`${API_BASE_URL}/sales`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(sale),
  });
  if (!response.ok) throw new Error(`Could not complete sale: ${response.status}`);
  return response.json();
}

export async function salesReport(storeId, cursor = null, search = "", dateFrom = "", dateTo = "", invoiceStatus = "") {
  const url = new URL(`${API_BASE_URL}/sales/report`);
  url.searchParams.set("store_id", storeId);
  if (cursor !== null) url.searchParams.set("cursor", `${cursor.date_create},${cursor.id}`);
  if (search) url.searchParams.set("search", search);
  if (dateFrom) url.searchParams.set("date_from", dateFrom);
  if (dateTo) url.searchParams.set("date_to", dateTo);
  if (invoiceStatus) url.searchParams.set("invoice_status", invoiceStatus);

  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load invoices: ${response.status}`);
  return response.json();
}

export async function saleDetails(saleId) {
  const response = await fetch(`${API_BASE_URL}/sales/${saleId}`);
  if (!response.ok) throw new Error(`Could not load invoice details: ${response.status}`);
  return response.json();
}

export async function addSalePayment(saleId, payment) {
  const response = await fetch(`${API_BASE_URL}/sales/${saleId}/payments`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payment),
  });
  if (!response.ok) throw new Error(`Could not record payment: ${response.status}`);
  return response.json();
}

export async function cancelSale(saleId) {
  const response = await fetch(`${API_BASE_URL}/sales/${saleId}/cancel`, { method: "POST" });
  if (!response.ok) throw new Error(`Could not cancel invoice: ${response.status}`);
  return response.json();
}
