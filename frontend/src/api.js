export const BASE_URL = import.meta.env.VITE_API_URL || '/api';

let accessToken = null;

export const setToken = (token) => {
    accessToken = token;
};

export const getToken = () => accessToken;

const isJsonResponse = (response) => {
    const contentType = response.headers.get('content-type') || '';
    return contentType.includes('application/json');
};

export const parseApiResponse = async (response) => {
    const body = await response.text();
    if (!body) {
        return {};
    }

    if (isJsonResponse(response)) {
        try {
            return JSON.parse(body);
        } catch (error) {
            throw new Error(`Invalid JSON response from API (status ${response.status})`);
        }
    }

    if (!response.ok) {
        throw new Error(`Unexpected non-JSON API response (status ${response.status})`);
    }

    return { message: body };
};

const buildHeaders = (customHeaders, token, hasBody) => {
    const headers = new Headers(customHeaders || {});
    if (!headers.has('Accept')) {
        headers.set('Accept', 'application/json');
    }
    if (hasBody && !headers.has('Content-Type')) {
        headers.set('Content-Type', 'application/json');
    }
    if (token) {
        headers.set('Authorization', `Bearer ${token}`);
    }
    return headers;
};

export const secureFetch = async (endpoint, options = {}) => {
    const makeRequest = (token) => fetch(`${BASE_URL}${endpoint}`, {
        ...options,
        headers: buildHeaders(options.headers, token, Boolean(options.body)),
        credentials: 'include',
    });

    let response = await makeRequest(getToken());

    if (response.status === 401 && !['/auth/login', '/auth/register', '/auth/refresh'].includes(endpoint)) {
        const refreshResponse = await fetch(`${BASE_URL}/auth/refresh`, {
            method: 'POST',
            credentials: 'include',
        });

        if (refreshResponse.ok) {
            try {
                const data = await parseApiResponse(refreshResponse);
                if (data.accessToken) {
                    setToken(data.accessToken);
                    response = await makeRequest(data.accessToken);
                } else {
                    setToken(null);
                }
            } catch (error) {
                setToken(null);
            }
        } else {
            setToken(null);
        }
    }

    return response;
};
