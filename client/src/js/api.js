export const API_BASE_URL = "http://localhost:4000/api";

export async function health() {
  const response = await fetch(`${API_BASE_URL}/health`);
  if (!response.ok) throw new Error(`Server health check failed: ${response.status}`);
  return response.json();
}

export async function activeProducts(storeId, cursor = null) {
  const url = new URL(`${API_BASE_URL}/products`);
  url.searchParams.set("store_id", storeId);
  if (cursor !== null) url.searchParams.set("cursor", cursor);

  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load products: ${response.status}`);
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

export async function inventorySummary(storeId) {
  const url = new URL(`${API_BASE_URL}/inventory/summary`);
  url.searchParams.set("store_id", storeId);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load inventory summary: ${response.status}`);
  return response.json();
}

export async function adjustInventory(adjustment) {
  const response = await fetch(`${API_BASE_URL}/inventory/adjustments`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(adjustment) });
  if (!response.ok) throw new Error(`Could not update inventory: ${response.status}`);
  return response.json();
}

export async function productOrders(storeId) {
  const url = new URL(`${API_BASE_URL}/product-orders`); url.searchParams.set("store_id", storeId);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load purchase orders: ${response.status}`);
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
  if (cursor !== null) url.searchParams.set("cursor", cursor);
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
