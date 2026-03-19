const apiUrl = import.meta.env.VITE_API_URL || '';

function withAuth(token) {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`
  };
}

export async function fetchCart(token) {
  const response = await fetch(`${apiUrl}/api/cart`, {
    headers: withAuth(token)
  });
  const data = await response.json();

  if (!response.ok || !data.success) {
    throw new Error(data.message || 'Failed to fetch cart');
  }

  return data.data.items || [];
}

export async function addCartItem(token, productId, quantity = 1) {
  const response = await fetch(`${apiUrl}/api/cart/items`, {
    method: 'POST',
    headers: withAuth(token),
    body: JSON.stringify({ productId, quantity })
  });
  const data = await response.json();

  if (!response.ok || !data.success) {
    throw new Error(data.message || 'Failed to add item to cart');
  }
}

export async function updateCartItem(token, productId, quantity) {
  const response = await fetch(`${apiUrl}/api/cart/items/${productId}`, {
    method: 'PATCH',
    headers: withAuth(token),
    body: JSON.stringify({ quantity })
  });
  const data = await response.json();

  if (!response.ok || !data.success) {
    throw new Error(data.message || 'Failed to update cart item');
  }
}

export async function removeCartItem(token, productId) {
  const response = await fetch(`${apiUrl}/api/cart/items/${productId}`, {
    method: 'DELETE',
    headers: withAuth(token)
  });
  const data = await response.json();

  if (!response.ok || !data.success) {
    throw new Error(data.message || 'Failed to remove cart item');
  }
}

export async function clearUserCart(token) {
  const response = await fetch(`${apiUrl}/api/cart`, {
    method: 'DELETE',
    headers: withAuth(token)
  });
  const data = await response.json();

  if (!response.ok || !data.success) {
    throw new Error(data.message || 'Failed to clear cart');
  }
}
