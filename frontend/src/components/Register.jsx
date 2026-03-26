import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { secureFetch } from '../api';

function Register() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ username: '', email: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const calculatePasswordStrength = (pwd) => {
    // Basic entropy check
    if (!pwd) return '';
    let strength = 0;
    if (pwd.length > 8) strength++;
    if (/[A-Z]/.test(pwd)) strength++;
    if (/[0-9]/.test(pwd)) strength++;
    if (/[^A-Za-z0-9]/.test(pwd)) strength++;
    return strength < 2 ? 'Weak' : strength < 4 ? 'Medium' : 'Strong';
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await secureFetch('/auth/register', {
        method: 'POST',
        body: JSON.stringify(formData)
      });

      const contentType = res.headers.get('content-type');
      if (!contentType || !contentType.includes('application/json')) {
        throw new Error(`API Unreachable (${res.status}). Is the Backend VM running?`);
      }

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.error || 'Registration failed');
      }
      navigate('/login');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <h3>Register</h3>
      {error && <p style={{color: 'red'}}>{error}</p>}
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
          <label>Email (Encrypted at rest)</label><br/>
          <input 
            required 
            type="email" 
            value={formData.email} 
            onChange={e => setFormData({...formData, email: e.target.value})} 
          />
        </div>
        <div>
          <label>Password</label><br/>
          <input 
            required 
            type="password" 
            autoComplete="new-password"
            value={formData.password} 
            onChange={e => setFormData({...formData, password: e.target.value})} 
          />
          <small>Strength: {calculatePasswordStrength(formData.password)}</small>
        </div>
        <button type="submit" disabled={loading}>
          {loading ? 'Submitting...' : 'Register'}
        </button>
      </form>
      <Link to="/login">Already have an account? Login</Link>
    </div>
  );
}

export default Register;