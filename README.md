# Full-Stack Security Assessment Deployment

This project implements a secure full-stack app aligned to `Fullstack-Security-Assessment 1.txt`:
- React frontend served behind an HTTPS reverse proxy
- Node.js/Express API with JWT auth + refresh cookie flow
- MongoDB with TLS, bcrypt password hashing, and AES-256-GCM field encryption at rest

## Architecture

1. VM 1 (`frontend` + `nginx` reverse proxy)
- Serves static React build over HTTPS
- Proxies `/api/*` requests to Backend VM
- Adds CSP, HSTS, X-Content-Type-Options, Referrer-Policy, and anti-clickjacking headers

2. VM 2 (`backend`)
- Express API with `helmet`, CORS allowlist, auth route rate limiting, and input validation
- Issues short-lived access tokens and HttpOnly/Secure/SameSite=Strict refresh cookie
- Uses access token in `Authorization: Bearer ...` for protected routes

3. VM 3 (`database`)
- MongoDB with TLS enabled and auth enabled
- Least-privilege app user (`readWrite` only on app DB)

## Security Controls Implemented

- Fail-fast env validation on server boot (`MONGO_URI`, JWT secrets, encryption key, allowed origin)
- AES-256-GCM for sensitive fields at rest (`email`, submitted protected records)
- bcrypt cost factor 12 for passwords
- CORS allowlist (no wildcard), rate limiting on `/auth/*`, standardized validation errors
- Refresh-token cookie hardening: `HttpOnly`, `Secure`, `SameSite=Strict`
- Token refresh flow with silent retry on 401 in frontend API wrapper
- Structured JSON audit logging with masked sensitive values

## VM Setup (Fully Automated)

All setup scripts are non-interactive and accept flags/env vars.

### 1) Database VM

```bash
cd vm-setup
./run-setup.sh database --backend-ip <backend_vm_ip>
```

This writes credentials to `/root/secure-db-credentials.env`.
The file includes DB credentials plus the MongoDB CA certificate payload used by backend TLS verification.

### 2) Backend VM

Copy the DB credentials file to backend VM, then:

```bash
cd vm-setup
./run-setup.sh backend \
  --creds-file /root/secure-db-credentials.env \
  --db-host <database_vm_ip> \
  --frontend-origin https://<frontend_vm_ip> \
  --proxy-ip <frontend_vm_ip>
```

### 3) Frontend VM

```bash
cd vm-setup
./run-setup.sh frontend --backend-host <backend_vm_ip>
```

App will be served at `https://<frontend_vm_ip>/`.

## Local Development

### Backend

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

## Notes

- For production, replace self-signed MongoDB certs with CA-signed certs and rotate DB/JWT/encryption secrets regularly.
- Keep `.env` files out of git and rotate secrets if leaked.
