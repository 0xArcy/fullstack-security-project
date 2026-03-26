import { useState, useEffect } from 'react';
import { secureFetch } from '../api';

function Dashboard({ onLogout }) {
  const [profile, setProfile] = useState(null);
  const [sensitiveData, setSensitiveData] = useState('');
  const [submissions, setSubmissions] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const res = await secureFetch('/data/profile');
        if (res.ok) {
          const data = await res.json();
          setProfile(data);
        } else {
          onLogout();
        }
      } catch (err) {
        setError('Failed to fetch profile.');
      }
    };
    fetchProfile();
  }, [onLogout]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const res = await secureFetch('/data/submit', {
        method: 'POST',
        body: JSON.stringify({ sensitiveData })
      });
      const data = await res.json();
      if (res.ok) {
        setSubmissions([...submissions, data.received]);
        setSensitiveData('');
      } else {
        setError(data.error);
      }
    } catch (err) {
      setError('Form submission failed.');
    }
  };

  const logout = async () => {
    await secureFetch('/auth/logout', { method: 'POST' });
    onLogout();
  };

  if (!profile) return <p>Loading Skeleton...</p>;

  return (
    <div>
      <h3>Dashboard</h3>
      <p>Welcome, <strong>{profile.username}</strong>!</p>
      <p>Your decrypted email: {profile.email}</p>
      
      <button onClick={logout}>Logout</button>

      <hr />
      
      <h4>Submit Protected Data</h4>
      {error && <p style={{color: 'red'}}>{error}</p>}
      <form onSubmit={handleSubmit}>
        <input 
          type="text" 
          value={sensitiveData} 
          onChange={(e) => setSensitiveData(e.target.value)} 
          placeholder="Try injecting <script>alert(1)</script>"
          required
        />
        <button type="submit">Submit</button>
      </form>

      <h4>Submissions (Secured against XSS)</h4>
      <ul>
        {submissions.map((sub, i) => (
          // In React, rendering inside standard elements uses textContent automatically (Anti-XSS by default).
          // NOT using dangerouslySetInnerHTML.
          <li key={i}>{sub}</li>
        ))}
      </ul>
    </div>
  );
}

export default Dashboard;