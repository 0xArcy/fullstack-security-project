import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { parseApiResponse, secureFetch } from '../api';

function Login({ onLogin }) {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ username: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const response = await secureFetch('/auth/login', {
        method: 'POST',
        body: JSON.stringify(formData),
      });

      const data = await parseApiResponse(response);
      if (!response.ok) {
        throw new Error(data.error || 'Login failed');
      }

      onLogin(data.accessToken); 
      navigate('/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <h3>Login</h3>
      {error && <p className="error-text">{error}</p>}
      <form onSubmit={handleSubmit}>
        <div>
          <label>Username</label><br/>
          <input 
            required 
            type="text" 
            value={formData.username} 
            onChange={e => setFormData({...formData, username: e.target.value})} 
          />
        </div>
        <div>
          <label>Password</label><br/>
          <input 
            required 
            type="password" 
            autoComplete="current-password"
            value={formData.password} 
            onChange={e => setFormData({...formData, password: e.target.value})} 
          />
        </div>
        <button type="submit" disabled={loading}>
          {loading ? 'Logging in...' : 'Login'}
        </button>
      </form>
      <Link to="/register">Create an account</Link>
    </div>
  );
}

export default Login;
