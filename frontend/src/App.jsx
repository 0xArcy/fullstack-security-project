import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Register from './components/Register';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import { parseApiResponse, secureFetch, setToken } from './api';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isBootstrapping, setIsBootstrapping] = useState(true);

  const handleLogin = (token) => {
    setToken(token);
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    setToken(null);
    setIsAuthenticated(false);
  };

  useEffect(() => {
    const restoreSession = async () => {
      try {
        const response = await secureFetch('/auth/refresh', { method: 'POST' });
        if (!response.ok) {
          setToken(null);
          setIsAuthenticated(false);
          return;
        }

        const data = await parseApiResponse(response);
        if (data.accessToken) {
          setToken(data.accessToken);
          setIsAuthenticated(true);
        } else {
          setToken(null);
          setIsAuthenticated(false);
        }
      } catch (error) {
        setToken(null);
        setIsAuthenticated(false);
      } finally {
        setIsBootstrapping(false);
      }
    };

    restoreSession();
  }, []);

  if (isBootstrapping) {
    return (
      <div>
        <h2>Secure Application</h2>
        <p>Loading...</p>
      </div>
    );
  }

  return (
    <BrowserRouter>
      <div>
        <h2>Secure Application</h2>
        <Routes>
          <Route path="/register" element={<Register />} />
          <Route path="/login" element={<Login onLogin={handleLogin} />} />
          <Route 
             path="/dashboard" 
             element={isAuthenticated ? <Dashboard onLogout={handleLogout} /> : <Navigate to="/login" />} 
          />
          <Route path="*" element={<Navigate to="/login" />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
