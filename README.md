# Full-Stack Security Assessment Deployment

This repository contains the automated setup scripts and source code for the Full-Stack Security Assessment project. It is designed to be deployed across three separate virtual machines (VMs) to ensure strict isolation and proper security layers.

## Architecture

1. **VM 1: Frontend & Proxy**
   - Serves the compiled React frontend.
   - Hosts the reverse web proxy (Nginx or Godproxy) handling incoming HTTPS traffic.
   - Enforces strict security headers (CSP, HSTS) and protects against XSS/CSRF.

2. **VM 2: Backend API**
   - Hosts the Node.js/Express application.
   - Processes business logic, JWT authentication, and input validation.
   - Connects to the Database VM over a secure Mongoose TLS connection.
   - Contains encryption mechanisms (AES-256-GCM) for sensitive data.

3. **VM 3: Database**
   - Hosts the MongoDB instance.
   - Only accepts TLS-encrypted incoming connections from the Backend VM.
   - Restricted database user with least-privilege access.

## VM Setup Scripts
Navigate to the `vm-setup/` directory for provisioning scripts that automate the installation of Node.js, MongoDB, and proxies. 
