# Secure Full-Stack Application: Assessor Walkthrough Guide

This document is designed to guide you through the presentation of the Secure Full-Stack Application, mapped specifically to the required assessment rubric. 

## 1. Environment & API Security (T-1.1 & T-2.1)

**Goal:** Demonstrate secure boot architecture, edge security, and explain the Nginx Reverse Proxy design.

*   **The Reverse Proxy Architecture (Going Beyond Basics):** Explain why you chose to use an Nginx reverse proxy (VM 1) instead of serving everything directly from Node.js:
    *   *SSL Offloading:* Node.js is single-threaded; forcing it to decrypt SSL/TLS traffic slows down the API. Nginx handles SSL decryption quickly at the network edge via optimized C code.
    *   *Edge Security:* Nginx intercepts malicious traffic, handles initial rate limiting, and injects strict security headers before requests even reach the application logic layer.
*   **Fail-Fast Boot:** Open `backend/server.js`. Point to the required environment variables array. Explain that the application uses a "fail-fast" boot mechanism. If crucial secrets like `MONGO_URI`, `JWT_SECRET`, or `FIELD_ENCRYPT_KEY` are missing from the configuration, the server refuses to start, preventing insecure fallback states.
*   **Security Headers:** Open the application in a browser and open the Network tab. Click on a network request and show the Response Headers injected by Nginx and Helmet:
    *   Show `Strict-Transport-Security` (HSTS) enforcing HTTPS.
    *   Show `Content-Security-Policy` and `X-Frame-Options` guarding against XSS and Clickjacking.
    *   Point out that the `X-Powered-By: Express` header is explicitly disabled via Helmet to prevent stack fingerprinting by attackers.
*   **CORS Whitelisting:** Explain that CORS is explicitly locked down to the frontend's origin via the `ALLOWED_ORIGIN` environment variable, rejecting wildcard `*` access.

## 2. Authentication Flow & JWTs (T-2.2 & T-3.1)

**Goal:** Demonstrate secure credential handling and XSS/CSRF mitigation.

*   **Login Flow:** Perform a live login in the browser while the DevTools Application/Storage tab is open.
*   **XSS Mitigation (Memory Storage):** Emphasize that the short-lived JWT Access Token is **never** stored in `localStorage` or `sessionStorage` (where it could be stolen by XSS). It is kept strictly in JavaScript memory.
*   **CSRF Mitigation (Secure Cookies):** Point to the browser's cookie storage. Show the Refresh Token cookie and highlight its flags:
    *   `HttpOnly`: Prevents JavaScript (XSS) from reading the token.
    *   `Secure`: Ensures the cookie is only sent over HTTPS.
    *   `SameSite=Strict`: Prevents the browser from sending the cookie on cross-site requests, mitigating CSRF attacks.

## 3. Data In Transit & Database Connection (T-1.2 & T-4.2)

**Goal:** Prove Zero-Trust internal network communication.

*   **Mutual TLS:** Show the Mongoose connection options in the backend code. Point out `tls: true` and the usage of custom Certificate Authority files. Explain that even on the internal private VM network, traffic between the Node.js API and MongoDB is mathematically encrypted.
*   **Least Privilege:** Explain that the database user created for the API does not have root access. It is restricted to the specific `secure_db` database with only `readWrite` permissions.

## 4. Encryption at Rest & Handling PII (T-1.3 & T-4.1)

**Goal:** Prove that stolen database files yield no plaintext PII or passwords.

*   **Live Database Proof:** (See the *MongoDB CLI Demonstration Guide* below for exact commands).
*   **Bcrypt Hashing:** Show a user document in the database and point out the `password` field, highlighting that it is hashed using bcrypt with a high work factor (12 rounds).
*   **AES-256-GCM Encryption:** Show a protected field (like `email` or sensitive record data). Point out that the data in the database is unreadable ciphertext. 
    *   **Explain the structure:** The string in the database contains the IV (Initialization Vector), the Authentication Tag, and the ciphertext. 
    *   **Defend GCM:** If asked why AES-256-GCM was chosen over CBC, explain that GCM provides *Authenticated Encryption*. The Auth Tag prevents an attacker with database access from secretly tampering with or corrupting the ciphertext (padding oracle attacks).

## 5. Input Validation & XSS Defense (T-2.3 & T-3.2)

**Goal:** Demonstrate robust application-layer injection defenses.

*   **XSS Attempt:** In the frontend application, attempt to inject the following payload into a form field: `<script>alert("XSS")</script>`.
*   **The Result:** Submit the form and show the result on the screen. Explain that because the frontend uses safe DOM generation (conceptually `textContent`) rather than `innerHTML`, the payload renders harmlessly as literal text on the screen instead of executing as code.

---

## 6. Threat Model Q&A Cheat Sheet (T-4.3)

*   **"If your database backup file is stolen, what data is the attacker able to read?"**
    *   Only non-sensitive metadata. Passwords are mathematically hashed, and sensitive PII is encrypted via application-layer AES-256-GCM. Without the master key from the backend `.env` file, the data is useless.
*   **"A junior dev accidentally commits the .env file. What's your incident response?"**
    *   Assume total compromise. Revoke all API keys, rotate database passwords, and initiate a key rotation for the `FIELD_ENCRYPT_KEY` (decrypting old DB entries and re-encrypting with a new key). Purge the commit history using `git filter-repo`.
*   **"Your access token expires. Walk me through exactly what happens in the browser."**
    *   The API returns a `401 Unauthorized`. The frontend logic intercepts this error, silently makes a request to `/api/auth/refresh` (which automatically includes the secure `HttpOnly` cookie), receives a new Access Token in memory, and immediately retries the failed request seamlessly.
*   **"What would you add to this application before putting it in front of real users?"**
    *   I would migrate away from `.env` files to a secure Secrets Manager (like AWS Secrets Manager/HashiCorp Vault), implement a Web Application Firewall (WAF), and configure automated anomaly alerting.
*   **"Explain the difference between authentication and authorisation."**
    *   Authentication is verifying *who* you are (login, verifying passwords). Authorization is verifying *what* you are allowed to do (ensuring User A cannot delete User B's records).

---

# MongoDB CLI Demonstration Guide

During your presentation, you will need to log into the database directly to prove that the data is encrypted at rest. Follow these steps on the **Database VM** terminal.

### Step 1: Connect to the Database
*Replace `secure_app_user` with your actual database user if different. Enter the password when prompted.*
```bash
mongosh -u "secure_app_user" -p --authenticationDatabase "admin" "mongodb://127.0.0.1:27017/secure_db?tls=true&tlsAllowInvalidCertificates=true"
```

### Step 2: Basic Navigation
Once inside the `mongosh>` prompt, run these commands to navigate:
```javascript
// Show which database you are currently using
db 

// Switch to your application's database
use secure_db

// List all collections (tables) in this database
show collections
// Expected output: users, records
```

### Step 3: Proving Encryption (The Crucial Step)

**1. Inspecting a User (Bcrypt and PII Encryption)**
```javascript
// Find the first user in the database and format it nicely
db.users.findOne()
```
*   **What to tell the evaluator:** "Look at the `password` field — it is securely hashed with bcrypt. Look at the `email` field — it is encrypted using AES-256-GCM. You can see the IV, the auth tag, and the ciphertext. I cannot read this user's email, fulfilling the data-at-rest requirement."

**2. Inspecting a Record (Data Encryption)**
```javascript
// Find the first stored record in the database
db.records.findOne()

// Alternatively, find all records (if you want to show a list)
db.records.find().pretty()
```
*   **What to tell the evaluator:** "Any sensitive data entered through the frontend form is mathematically encrypted before it ever reaches this database server."

### Step 4: Deleting/Manipulating Data (Optional, if asked)
If the evaluator asks you to prove you have write access, or you want to show how to clear data:
```javascript
// Count how many users exist
db.users.countDocuments()

// Delete a specific user by their username
db.users.deleteOne({ username: "testuser" })

// DANGER: Delete ALL users (Wipe the collection)
db.users.deleteMany({})

// Exit the MongoDB shell and return to Linux
exit
```