const API_BASE_URL = "http://localhost:4000/api";

export async function health() {
  const response = await fetch(`${API_BASE_URL}/health`);
  if (!response.ok) throw new Error(`Server health check failed: ${response.status}`);
  return response.json();
}

export async function activeProducts(cursor = null) {
  const url = new URL(`${API_BASE_URL}/products`);
  if (cursor !== null) url.searchParams.set("cursor", cursor);

  const response = await fetch(url);
  if (!response.ok) throw new Error(`Could not load products: ${response.status}`);
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
