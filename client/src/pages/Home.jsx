import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { Link } from 'react-router-dom';
import { getProducts } from '../api/products';
import { useCart } from '../context/CartContext';

function Home() {
  const [healthData, setHealthData] = useState(null);
  const [products, setProducts] = useState([]);
  const [productsLoading, setProductsLoading] = useState(true);
  const [productsError, setProductsError] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [cartNotice, setCartNotice] = useState('');
  const { user, logout, isAuthenticated } = useAuth();
  const { items, addToCart, removeFromCart, updateQuantity, clearCart, cartCount, cartTotal } =
    useCart();

  useEffect(() => {
    const apiUrl = import.meta.env.VITE_API_URL || '';
    fetch(`${apiUrl}/api/health`)
      .then((res) => res.json())
      .then((data) => setHealthData(data))
      .catch((err) => console.error('Error fetching health check:', err));

    getProducts()
      .then((data) => {
        setProducts(data);
      })
      .catch((err) => {
        console.error('Error fetching products:', err);
        setProductsError('Could not load products right now.');
      })
      .finally(() => {
        setProductsLoading(false);
      });
  }, []);

  const filteredProducts = useMemo(() => {
    const normalized = searchQuery.trim().toLowerCase();
    if (!normalized) {
      return products;
    }

    return products.filter((product) => {
      return [product.name, product.category, product.description]
        .join(' ')
        .toLowerCase()
        .includes(normalized);
    });
  }, [products, searchQuery]);

  const handleAddToCart = async (product) => {
    const result = await addToCart(product);
    if (!result.success) {
      setCartNotice(result.message || 'Could not update cart.');
      return;
    }

    setCartNotice(`${product.name} added to your cart.`);
  };

  return (
    <main className="container storefront">
      <header className="store-topbar">
        <h1>ShopSmart</h1>
        <div className="store-actions">
          <div className="cart-pill" data-testid="cart-count-pill">
            Cart: {cartCount} item{cartCount === 1 ? '' : 's'}
          </div>
          {isAuthenticated ? (
            <div className="user-section">
              <p className="welcome-text">Welcome, {user.firstName || user.email}!</p>
              <button onClick={logout} className="logout-button" data-testid="logout-button">
                Logout
              </button>
            </div>
          ) : (
            <div className="auth-links">
              <Link to="/login" className="nav-link" data-testid="login-link">
                Login
              </Link>
              <Link to="/signup" className="nav-link nav-link-primary" data-testid="signup-link">
                Sign Up
              </Link>
            </div>
          )}
        </div>
      </header>

      <section className="hero-shell" aria-label="hero">
        <p className="hero-kicker">Spring deals</p>
        <p className="hero-subtitle">
          Discover quality tech products curated for your daily needs.
        </p>
        <div className="hero-meta">
          <span>Free shipping over $50</span>
          <span>2-year warranty</span>
          <span>Fast checkout</span>
        </div>
      </section>

      <section className="card products-section" aria-label="products-listing">
        <div className="section-head">
          <h2>Featured Products</h2>
          <p>Handpicked items with premium quality and competitive pricing.</p>
        </div>
        <div className="catalog-toolbar">
          <input
            type="search"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            placeholder="Search products by name, category, or description"
            className="search-input"
            aria-label="Search products"
          />
          <p className="results-count">
            Showing {filteredProducts.length} of {products.length} products
          </p>
        </div>
        {cartNotice ? <p className="cart-notice">{cartNotice}</p> : null}
        {productsLoading ? <p>Loading products...</p> : null}
        {!productsLoading && productsError ? <p role="alert">{productsError}</p> : null}
        {!productsLoading && !productsError ? (
          <div className="products-grid" data-testid="products-grid">
            {filteredProducts.map((product) => (
              <article
                key={product.id}
                className="product-card"
                data-testid={`product-card-${product.id}`}
              >
                <img src={product.image} alt={product.name} className="product-image" />
                <div className="product-card-content">
                  <p className="product-category">{product.category}</p>
                  <h3>{product.name}</h3>
                  <p className="product-description">{product.description}</p>
                  <div className="product-footer">
                    <span className="product-price">${Number(product.price).toFixed(2)}</span>
                    <div className="product-actions">
                      <button
                        type="button"
                        className="add-cart-button"
                        onClick={() => {
                          handleAddToCart(product);
                        }}
                      >
                        Add to cart
                      </button>
                      <Link
                        className="view-details-link"
                        to={`/products/${product.id}`}
                        data-testid={`product-link-${product.id}`}
                      >
                        View details
                      </Link>
                    </div>
                  </div>
                </div>
              </article>
            ))}
          </div>
        ) : null}
        {!productsLoading && !productsError && filteredProducts.length === 0 ? (
          <p className="empty-state">No products match your search right now.</p>
        ) : null}
      </section>

      <section className="card cart-section" aria-label="shopping-cart">
        <div className="cart-head">
          <h2>Shopping Cart</h2>
          {items.length > 0 ? (
            <button
              type="button"
              className="clear-cart-button"
              onClick={() => {
                clearCart();
              }}
            >
              Clear cart
            </button>
          ) : null}
        </div>
        {!isAuthenticated ? <p>Login required to save and manage your cart.</p> : null}
        {items.length === 0 ? <p>Your cart is empty. Add products to get started.</p> : null}
        {items.length > 0 ? (
          <>
            <ul className="cart-list">
              {items.map((item) => (
                <li className="cart-item" key={item.id}>
                  <div>
                    <p className="cart-item-name">{item.name}</p>
                    <p className="cart-item-meta">${Number(item.price).toFixed(2)} each</p>
                  </div>
                  <div className="cart-item-actions">
                    <button
                      type="button"
                      onClick={() => updateQuantity(item.id, item.quantity - 1)}
                      aria-label={`Decrease quantity for ${item.name}`}
                    >
                      -
                    </button>
                    <span>{item.quantity}</span>
                    <button
                      type="button"
                      onClick={() => updateQuantity(item.id, item.quantity + 1)}
                      aria-label={`Increase quantity for ${item.name}`}
                    >
                      +
                    </button>
                    <button
                      type="button"
                      className="remove-item-button"
                      onClick={() => removeFromCart(item.id)}
                    >
                      Remove
                    </button>
                  </div>
                </li>
              ))}
            </ul>
            <p className="cart-total">Total: ${cartTotal.toFixed(2)}</p>
          </>
        ) : null}
      </section>

      <section className="status-panel card">
        <h2>Backend Status</h2>
        {healthData ? (
          <div className="status-grid">
            <p>
              Status: <span className="status-ok">{healthData.status}</span>
            </p>
            <p>Message: {healthData.message}</p>
            <p>Timestamp: {healthData.timestamp}</p>
          </div>
        ) : (
          <p>Loading backend status...</p>
        )}
      </section>
    </main>
  );
}

export default Home;
