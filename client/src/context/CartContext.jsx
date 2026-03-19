import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useAuth } from './AuthContext';
import { addCartItem, clearUserCart, fetchCart, removeCartItem, updateCartItem } from '../api/cart';

const CartContext = createContext(null);

export function CartProvider({ children }) {
  const [items, setItems] = useState([]);
  const [isSyncing, setIsSyncing] = useState(false);
  const { token, isAuthenticated } = useAuth();

  const ensureAuthenticated = () => {
    if (!isAuthenticated || !token) {
      return {
        success: false,
        message: 'Please log in to manage your cart.'
      };
    }

    return { success: true };
  };

  const refreshCart = useCallback(async () => {
    if (!isAuthenticated || !token) {
      setItems([]);
      return;
    }

    try {
      setIsSyncing(true);
      const nextItems = await fetchCart(token);
      setItems(nextItems);
    } catch (error) {
      console.error('Failed to load user cart:', error);
      setItems([]);
    } finally {
      setIsSyncing(false);
    }
  }, [isAuthenticated, token]);

  useEffect(() => {
    refreshCart();
  }, [refreshCart]);

  const addToCart = async (product) => {
    const auth = ensureAuthenticated();
    if (!auth.success) {
      return auth;
    }

    try {
      await addCartItem(token, product.id, 1);
      await refreshCart();
      return { success: true };
    } catch (error) {
      return {
        success: false,
        message: error.message || 'Failed to add item to cart.'
      };
    }
  };

  const removeFromCart = async (productId) => {
    const auth = ensureAuthenticated();
    if (!auth.success) {
      return auth;
    }

    try {
      await removeCartItem(token, productId);
      await refreshCart();
      return { success: true };
    } catch (error) {
      return {
        success: false,
        message: error.message || 'Failed to remove item.'
      };
    }
  };

  const updateQuantity = async (productId, quantity) => {
    const auth = ensureAuthenticated();
    if (!auth.success) {
      return auth;
    }

    try {
      await updateCartItem(token, productId, quantity);
      await refreshCart();
      return { success: true };
    } catch (error) {
      return {
        success: false,
        message: error.message || 'Failed to update quantity.'
      };
    }
  };

  const clearCart = async () => {
    const auth = ensureAuthenticated();
    if (!auth.success) {
      return auth;
    }

    try {
      await clearUserCart(token);
      await refreshCart();
      return { success: true };
    } catch (error) {
      return {
        success: false,
        message: error.message || 'Failed to clear cart.'
      };
    }
  };

  const cartCount = useMemo(() => items.reduce((total, item) => total + item.quantity, 0), [items]);

  const cartTotal = useMemo(
    () => items.reduce((total, item) => total + item.quantity * Number(item.price), 0),
    [items]
  );

  const value = {
    items,
    addToCart,
    removeFromCart,
    updateQuantity,
    clearCart,
    cartCount,
    cartTotal,
    isSyncing,
    refreshCart
  };

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
}
