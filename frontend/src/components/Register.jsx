import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { parseApiResponse, secureFetch } from '../api';

function Register() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ username: '', email: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const calculatePasswordStrength = (password) => {
    if (!password) return '';

    let poolSize = 0;
    if (/[a-z]/.test(password)) poolSize += 26;
    if (/[A-Z]/.test(password)) poolSize += 26;
    if (/[0-9]/.test(password)) poolSize += 10;
    if (/[^A-Za-z0-9]/.test(password)) poolSize += 33;

    if (poolSize === 0) return 'Weak';

    const entropyBits = Math.log2(poolSize) * password.length;

    if (entropyBits < 40) return `Weak (${Math.round(entropyBits)} bits)`;
    if (entropyBits < 60) return `Medium (${Math.round(entropyBits)} bits)`;
    return `Strong (${Math.round(entropyBits)} bits)`;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const response = await secureFetch('/auth/register', {
        method: 'POST',
        body: JSON.stringify(formData),
      });

      const data = await parseApiResponse(response);

      if (!response.ok) {
        throw new Error(data.error || 'Registration failed');
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
