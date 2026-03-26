import { useState, useEffect } from 'react';
import { parseApiResponse, secureFetch } from '../api';

function Dashboard({ onLogout }) {
  const [profile, setProfile] = useState(null);
  const [sensitiveData, setSensitiveData] = useState('');
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const [profileResponse, recordsResponse] = await Promise.all([
          secureFetch('/data/profile'),
          secureFetch('/data/records'),
        ]);

        if (!profileResponse.ok || !recordsResponse.ok) {
          onLogout();
          return;
        }

        const profileData = await parseApiResponse(profileResponse);
        const recordsData = await parseApiResponse(recordsResponse);
        setProfile(profileData);
        setRecords(Array.isArray(recordsData.records) ? recordsData.records : []);
      } catch (error) {
        setError('Failed to load dashboard data.');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, [onLogout]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      const response = await secureFetch('/data/submit', {
        method: 'POST',
        body: JSON.stringify({ sensitiveData }),
      });

      const data = await parseApiResponse(response);
      if (!response.ok) {
        throw new Error(data.error || 'Form submission failed');
      }

      if (data.record) {
        setRecords((prevRecords) => [data.record, ...prevRecords]);
        setSensitiveData('');
      }
    } catch (error) {
      setError(error.message || 'Form submission failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const logout = async () => {
    await secureFetch('/auth/logout', { method: 'POST' });
    onLogout();
  };

  if (loading) return <p>Loading dashboard...</p>;
  if (!profile) return <p>Session expired.</p>;

  return (
    <div>
      <h3>Dashboard</h3>
      <p>Welcome, <strong>{profile.username}</strong>!</p>
      <p>Your decrypted email: {profile.email}</p>
      
      <button onClick={logout}>Logout</button>

      <hr />
      
      <h4>Submit Protected Data</h4>
      {error && <p className="error-text">{error}</p>}
      <form onSubmit={handleSubmit}>
        <input 
          type="text" 
          value={sensitiveData} 
          onChange={(e) => setSensitiveData(e.target.value)} 
          placeholder="Try injecting <script>alert(1)</script>"
          required
        />
        <button type="submit" disabled={submitting}>
          {submitting ? 'Submitting...' : 'Submit'}
        </button>
      </form>

      <h4>Submissions (Secured against XSS)</h4>
      <ul>
        {records.map((record) => (
          <li key={record.id}>
            {record.sensitiveData}
          </li>
        ))}
      </ul>
    </div>
  );
}

export default Dashboard;
