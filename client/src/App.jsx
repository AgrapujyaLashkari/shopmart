import { BrowserRouter as Router, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { CartProvider } from './context/CartContext';
import Home from './pages/Home';
import Login from './pages/Login';
import Signup from './pages/Signup';
import ProductDetails from './pages/ProductDetails';

function PublicOnlyRoute({ children }) {
  const { isAuthenticated, loading, token } = useAuth();

  if (loading && token) {
    return <main className="container">Loading...</main>;
  }

  return isAuthenticated ? <Navigate to="/" replace /> : children;
}

// AppRoutes component for testing (can be wrapped in different routers)
export function AppRoutes() {
  return (
    <AuthProvider>
      <CartProvider>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route
            path="/login"
            element={
              <PublicOnlyRoute>
                <Login />
              </PublicOnlyRoute>
            }
          />
          <Route
            path="/signup"
            element={
              <PublicOnlyRoute>
                <Signup />
              </PublicOnlyRoute>
            }
          />
          <Route path="/products/:id" element={<ProductDetails />} />
        </Routes>
      </CartProvider>
    </AuthProvider>
  );
}

// Main App component with Router for production
function App() {
  return (
    <Router>
      <AppRoutes />
    </Router>
  );
}

export default App;
