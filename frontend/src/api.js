export const BASE_URL = import.meta.env.VITE_API_URL || '/api';

// Global Token state. NEVER stored in localStorage/sessionStorage.
let accessToken = null;

export const setToken = (token) => {
    accessToken = token;
};

export const getToken = () => accessToken;

// Centralized Fetch wrapper that intercepts 401s to initiate silent refresh
export const secureFetch = async (endpoint, options = {}) => {
    let currentToken = getToken();

    const requestConfig = {
        ...options,
        headers: {
            'Content-Type': 'application/json',
            ...(currentToken && { Authorization: `Bearer ${currentToken}` }),
            ...options.headers,
        },
        credentials: 'include' // VERY IMPORTANT: Sends the HttpOnly secure refreshToken cookie
    };

    let response = await fetch(`${BASE_URL}${endpoint}`, requestConfig);

    // If 401 (Expired), attempt silent refresh
    if (response.status === 401 && endpoint !== '/auth/login' && endpoint !== '/auth/refresh') {
        const refreshResponse = await fetch(`${BASE_URL}/auth/refresh`, {
            method: 'POST',
            credentials: 'include'
        });

        if (refreshResponse.ok) {
            const data = await refreshResponse.json();
            setToken(data.accessToken); // Update memory token

            // Retry original request with NEW token
            requestConfig.headers.Authorization = `Bearer ${data.accessToken}`;
            response = await fetch(`${BASE_URL}${endpoint}`, requestConfig);
        } else {
            // Refresh failed (user truly logged out)
            setToken(null);
            window.location.href = '/login'; 
        }
    }

    return response;
};