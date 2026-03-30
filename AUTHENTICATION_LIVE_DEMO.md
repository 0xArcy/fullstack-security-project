# Live Demonstration: Authentication Flow & JWTs

This guide provides step-by-step instructions on how to perform the live demonstration for **Section 2: Authentication Flow & JWTs (T-2.2 & T-3.1)** to your evaluator.

## ⚙️ Preparation
1. Open your frontend application URL in a modern web browser (e.g., Google Chrome or Mozilla Firefox).
2. Open the **Developer Tools** (Press `F12` or Right-click -> `Inspect`).
3. Navigate to the **Application** tab (in Chrome/Edge) or **Storage** tab (in Firefox).

---

## 🚀 Step 1: The Login Flow
1. In the browser, navigate to your application's Login page.
2. In the Developer Tools on the left sidebar, clear any existing data in **Local Storage**, **Session Storage**, and **Cookies** (right-click and clear) to ensure you start with a clean slate.
3. Keep the Developer Tools visible and focused on the **Application** (or Storage) tab.
4. Tell the evaluator: *"I am going to perform a live login while observing the browser's storage mechanisms."*
5. Enter your test credentials (username/email and password) into the login form.
6. Click the **Login** button.

---

## 🛡️ Step 2: Demonstrating XSS Mitigation (Memory Storage)
1. **Explain:** *"An attacker exploiting a Cross-Site Scripting (XSS) vulnerability can easily read data stored in Local Storage or Session Storage using simple JavaScript like `localStorage.getItem()`."*
2. **Show Local Storage:** In the Developer Tools, expand **Local Storage** and click on your application's domain. 
   * **Action:** Point out to the evaluator that no JWTs or sensitive tokens are stored here.
3. **Show Session Storage:** Expand **Session Storage** and click on your application's domain. 
   * **Action:** Point out that it is also free of authentication tokens.
4. **Explain the Defense:** *"As you can see, our short-lived JWT Access Token is **never** explicitly stored in `localStorage` or `sessionStorage`. Instead, it is kept strictly in isolated JavaScript memory (a variable). This means an attacker performing XSS cannot scrape the access token from the browser's storage."*

---

## 🔒 Step 3: Demonstrating CSRF Mitigation (Secure Cookies)
1. **Navigate to Cookies:** In the Developer Tools, expand the **Cookies** section and click on your application's domain.
2. **Point out the Refresh Token:** Highlight the newly created cookie (usually named `refreshToken` or similar). 
3. **Explain the Mechanism:** *"While the access token lives in memory, we use a Refresh Token to maintain the user's long-term session. However, this is stored securely to prevent Cross-Site Request Forgery (CSRF) and deeper XSS attacks."*
4. **Show & Explain the Cookie Flags (Point to each column in DevTools):**
    *   **HttpOnly Flag (Look for the checkmark in the 'HTTP' column):** 
        *   *"Notice the HttpOnly flag is set. This prevents client-side JavaScript from ever reading the token. Even if an attacker executes an XSS payload, calling `document.cookie` will not reveal this refresh token."*
    *   **Secure Flag (Look for the checkmark in the 'Secure' column):** 
        *   *"The Secure flag ensures that the browser will only transmit this cookie over an encrypted HTTPS connection, protecting it from network interception or Man-in-the-Middle attacks."*
    *   **SameSite Flag (Look for 'Strict' in the 'SameSite' column):** 
        *   *"Finally, the SameSite attribute is set to Strict. This tells the browser to never send this cookie along with cross-site requests. If an attacker on a malicious site tries to coerce the user's browser into making a request to our API (a CSRF attack), the browser will strip this auth cookie, causing the malicious request to fail."*

---

## ✅ Wrap-Up Statement
Conclude this section of the demonstration by saying: 
*"By isolating the short-lived access token in memory and locking down the refresh token inside an `HttpOnly`, `Secure`, and `SameSite=Strict` cookie, we have implemented a defense-in-depth strategy that effectively mitigates both XSS token theft and CSRF attacks."*