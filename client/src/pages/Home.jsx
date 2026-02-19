import { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { Link } from 'react-router-dom';

function Home() {
  const [healthData, setHealthData] = useState(null);
  const { user, logout, isAuthenticated } = useAuth();

  useEffect(() => {
    const apiUrl = import.meta.env.VITE_API_URL || '';
    fetch(`${apiUrl}/api/health`)
      .then(res => res.json())
      .then(data => setHealthData(data))
      .catch(err => console.error('Error fetching health check:', err));
  }, []);

  return (
    <div className="container">
      <h1>ShopSmart</h1>
      
      {isAuthenticated ? (
        <div className="user-section">
          <p>Welcome, {user.firstName || user.email}!</p>
          <button 
            onClick={logout} 
            className="logout-button"
            data-testid="logout-button"
          >
            Logout
          </button>
        </div>
      ) : (
        <div className="auth-links">
          <Link to="/login" className="nav-link" data-testid="login-link">Login</Link>
          <Link to="/signup" className="nav-link" data-testid="signup-link">Sign Up</Link>
        </div>
      )}

      <div className="card">
        <h2>Backend Status</h2>
        {healthData ? (
          <div>
            <p>Status: <span className="status-ok">{healthData.status}</span></p>
            <p>Message: {healthData.message}</p>
            <p>Timestamp: {healthData.timestamp}</p>
          </div>
        ) : (
          <p>Loading backend status...</p>
        )}
      </div>
    </div>
  );
}

export default Home;
