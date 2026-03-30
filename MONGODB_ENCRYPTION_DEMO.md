# Live Demonstration: Encryption at Rest (Data in MongoDB)

This guide provides the exact terminal steps to prove to your evaluator that data stored on the database server is completely unreadable without the application's master encryption keys.

## ⚙️ Preparation
1. Ensure your application is running, and you have registered at least one test user with an email and password through the frontend.
2. Open a terminal window connected directly to your **Database VM**.

---

## 🚀 Step 1: Connecting to MongoDB
In the terminal of the Database VM, log into the MongoDB shell. Use the exact administrative or application database user you configured.

1. **Type the connection command:**
   ```bash
   mongosh -u "secure_app_user" -p --authenticationDatabase "admin" "mongodb://127.0.0.1:27017/secure_db?tls=true&tlsAllowInvalidCertificates=true"
   ```
   *(Note: Replace `"secure_app_user"` and `"secure_db"` with your actual database user and database name if they differ).*
2. **Enter the password** when prompted.

---

## 📂 Step 2: Navigating to the Data
Once you see the `mongosh>` prompt, execute the following commands to navigate to your tables.

1. **Select the correct database:**
   ```javascript
   use secure_db
   ```
2. **Verify collections exist:**
   ```javascript
   show collections
   ```
   *(You should see `users` and/or `records` outputted to the screen).*

---

## 🛡️ Step 3: Proving Passwords are Hashed
1. **Query a single user document:**
   ```javascript
   db.users.findOne()
   ```
2. **What to say to the evaluator:** 
   Point directly to the output on the screen. 
   *"Here in the database, you can see the raw storage format of the user document. If an attacker stole the physical disk or obtained a database dump, this is all they would get. Let's look at the `password` field. It is not stored in plaintext; it is protected by a strong, mathematically mathematically irreversible bcrypt hash."*

---

## 🔒 Step 4: Proving PII is Encrypted (AES-256-GCM)
1. **Observe the PII field (e.g., email or personal data):** Look at the same `findOne()` output, specifically at a sensitive field like `email` or `data` inside the `records` collection.
   ```javascript
   // If you need to show the records collection instead:
   db.records.findOne()
   ```
2. **What to say to the evaluator:**
   Point to the encrypted field.
   *"Now let's look at the Personally Identifiable Information (PII), such as the email address. Rather than just relying on disk-level encryption, we implemented Application-Level Field Encryption using AES-256-GCM."*
3. **Break down the ciphertext:**
   *"Notice the structure. The data is entirely unreadable ciphertext. You'll also notice the IV (Initialization Vector) and the Auth Tag stored alongside it. The Auth Tag is critical here—because GCM provides Authenticated Encryption, it guarantees that a malicious actor with direct database access cannot secretly tamper with or alter this ciphertext without failing the integrity check upon decryption."*

---

## ✅ Wrap-Up Statement
Conclude this demonstration by typing `exit` to leave the `mongosh` terminal, and say:

*"Because this encryption happens at the application layer inside the Node.js API, this database server holds zero knowledge of the plaintext data. Even a total compromise of this database VM yields no usable passwords or PII."*