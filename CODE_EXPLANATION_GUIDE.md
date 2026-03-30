# Code Explanation Guide: Security Implementations

If the evaluator asks you to "look under the hood" and explain how the security features are implemented in the code, use this guide to navigate the codebase and explain your logic.

## 1. Authentication & Secure Cookies (Backend)
**Goal:** Show how the JWT Refresh Token is securely delivered to the browser.
**File to open:** `backend/routes/auth.js` (or your authentication controller)

**What to highlight:**
Locate the login route where the response is sent back to the client. Point out the `res.cookie()` function.

```javascript
// Example of what to point out:
res.cookie('refreshToken', refreshToken, {
    httpOnly: true,  // The most important flag for XSS mitigation
    secure: process.env.NODE_ENV === 'production', // Forces HTTPS
    sameSite: 'strict', // Mitigates CSRF
    maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
});
```
**Explanation to Evaluator:** 
*"Here in the backend login controller, when a user successfully authenticates, we generate both an Access Token and a Refresh Token. Notice that we don't send the Refresh Token in the JSON body. We attach it directly to the response as a cookie with strictly defined security flags. The `httpOnly` flag is hardcoded to `true`, establishing our primary defense against XSS token theft."*

## 2. In-Memory Token Storage (Frontend)
**Goal:** Show how the React frontend safely handles the short-lived access token.
**File to open:** `frontend/src/api.js` or `frontend/src/App.jsx` (wherever auth state is managed)

**What to highlight:**
Find the variable or state hook where the access token is stored (e.g., `const [accessToken, setAccessToken] = useState(null);` or a module-level variable).

**Explanation to Evaluator:**
*"On the frontend, when we receive the login response containing the short-lived Access Token, we immediately store it in local state (or a context provider). You will not see `localStorage.setItem('token', ...)` anywhere in this codebase. By confining the token to JavaScript memory, it is destroyed if the tab is closed, and it is entirely inaccessible to malicious scripts that might attempt to scrape `localStorage`."*

## 3. Database Field Level Encryption (Backend)
**Goal:** Show how sensitive data is encrypted before saving to MongoDB.
**File to open:** `backend/models/User.js` or `backend/utils/fieldEncryption.js`

**What to highlight:**
Show the preprocessing hook (like a Mongoose `pre('save')` hook) or the encryption utility function where AES-256-GCM is applied.

**Explanation to Evaluator:**
*"Before any PII (like email addresses or private records) is written to the database, we intercept the save operation at the Object-Document Mapper (Mongoose) level. We use Node's native `crypto` module to encrypt the plaintext using AES-256-GCM. The database only ever receives the resulting ciphertext, Initialization Vector (IV), and Authentication Tag."*

**Q&A: Why AES-256-GCM?**
If the evaluator asks why you chose GCM (Galois/Counter Mode) specifically, use this answer:
> *"I chose AES-256-GCM because it provides **Authenticated Encryption**. Older encryption modes (like CBC) only hide the data. If a hacker got into the database and randomly altered the encrypted text (a bit-flipping attack), older modes would just decrypt it into a corrupted string. GCM calculates an **Authentication Tag** alongside the ciphertext. If a hacker alters even a single character of the encrypted data in MongoDB, the Auth Tag becomes invalid. When my backend tries to decrypt it, GCM instantly detects the tampering, rejects the decryption, and throws an error, protecting the application's integrity."*

## 4. Password Hashing (Backend)
**Goal:** Show that passwords are never stored in plaintext.
**File to open:** `backend/models/User.js`

**What to highlight:**
Look for the `bcrypt.hash()` function in the user creation or pre-save logic.

**Explanation to Evaluator:**
*"For passwords, encryption is not the correct cryptographic tool since we never need to decrypt them. Instead, we use one-way hashing via bcrypt with a high salt rounds factor (e.g., 12 rounds). This ensures that even if the database is completely compromised, the passwords remain secure against brute-force and rainbow table attacks."*
