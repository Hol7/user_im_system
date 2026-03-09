# ✅ SIMPLIFIED OTP Verification - No More otpId Required!

## 🎉 What Changed

**Before (Confusing):**
- Required BOTH `otpId` AND `code`
- Had to query database to get `otpId`
- Two-step process was complicated

**After (Simple):**
- **Only requires the 6-digit `code` from your email**
- No database queries needed
- Just paste the code and verify!

---

## 🚀 New Simplified Flow

### Step 1: Register
```graphql
mutation {
  register(input: {
    email: "test@example.com"
    password: "SecurePass123!"
    passwordConfirmation: "SecurePass123!"
    firstName: "John"
    lastName: "Doe"
    phone: "+1234567890"
    country: "USA"
    city: "New York"
  }) {
    user {
      id
      email
      status
    }
    message
  }
}
```

### Step 2: Check Your Email
You'll receive an email with a **6-digit code**, for example:
```
Your verification code: 123456
```

### Step 3: Verify with Just the Code!
```graphql
mutation {
  verifyOtp(code: "123456") {
    user {
      id
      email
      status
    }
    token
    refreshToken
  }
}
```

**That's it!** No more `otpId` needed! 🎉

---

## 📧 Complete Examples

### Example 1: Email Verification After Registration

**GraphQL:**
```graphql
mutation VerifyEmail {
  verifyOtp(code: "123456") {
    user {
      id
      email
      status
      profile {
        firstName
        lastName
      }
    }
    token
    refreshToken
  }
}
```

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { verifyOtp(code:\"123456\") { user { id email status } token refreshToken } }"}' \
  http://localhost:4000/api/graphql
```

### Example 2: Login with OTP

**Step 1: Login**
```graphql
mutation {
  login(
    email: "test@example.com"
    password: "SecurePass123!"
  ) {
    message
    otpId
  }
}
```

**Step 2: Check email for code, then verify**
```graphql
mutation {
  verifyOtp(code: "789012") {
    user {
      id
      email
    }
    token
    refreshToken
  }
}
```

---

## 🔧 How It Works Behind the Scenes

1. **You enter the code:** Just the 6 digits from your email
2. **System searches:** Finds all unused, non-expired OTPs
3. **System verifies:** Checks which OTP matches your code
4. **System responds:** Returns your user data and JWT tokens

**Security:** The code is hashed in the database using Argon2, so it's secure even if someone accesses the database.

---

## ⏰ OTP Details

- **Length:** 6 digits (e.g., "123456")
- **Validity:** 1 hour (60 minutes)
- **Single Use:** Can only be used once
- **Purpose Types:**
  - `email_verification` - After registration
  - `login` - Two-factor authentication
  - `password_reset` - Reset your password

---

## 🎯 GraphiQL Examples

Open GraphiQL at: http://localhost:4000/api/graphiql

### Test Registration + Verification

```graphql
# 1. Register
mutation Step1_Register {
  register(input: {
    email: "demo@example.com"
    password: "SecurePass123!"
    passwordConfirmation: "SecurePass123!"
    firstName: "Demo"
    lastName: "User"
    phone: "+1234567890"
    country: "USA"
    city: "Boston"
  }) {
    user {
      id
      email
      status
    }
    message
  }
}

# 2. Check your email for the 6-digit code

# 3. Verify (replace 123456 with your actual code)
mutation Step2_Verify {
  verifyOtp(code: "123456") {
    user {
      id
      email
      status
    }
    token
    refreshToken
  }
}
```

### Test Login Flow

```graphql
# 1. Login
mutation LoginStep1 {
  login(
    email: "demo@example.com"
    password: "SecurePass123!"
  ) {
    message
    otpId
  }
}

# 2. Check email for code

# 3. Verify OTP
mutation LoginStep2 {
  verifyOtp(code: "789012") {
    user {
      id
      email
    }
    token
    refreshToken
  }
}
```

---

## 🐛 Troubleshooting

### Error: "Invalid or expired OTP code"

**Possible Causes:**
1. ✗ Wrong code (typo)
2. ✗ OTP expired (older than 1 hour)
3. ✗ OTP already used
4. ✗ No matching OTP in database

**Solutions:**
- Double-check the code from your email
- Make sure you're using the most recent email
- Register/login again to get a new code

### No Email Received

**Check:**
1. Server is running: `./load_env.sh`
2. BREVO_API_KEY is set in `.env`
3. Check spam/junk folder
4. Check Oban dashboard: http://localhost:4000/oban

### Code Not Working

**Try:**
```bash
# Check if there are any unused OTPs in database
psql -U bititi -d my_auth_system_dev -c "SELECT id, purpose, used, expires_at FROM otps WHERE used = false ORDER BY inserted_at DESC LIMIT 5;"
```

If you see expired OTPs, register/login again to get a fresh code.

---

## 📊 Comparison: Old vs New

| Feature | Old Method | New Method |
|---------|-----------|------------|
| Parameters | `otpId` + `code` | `code` only |
| Database Query | Required | Not needed |
| User Experience | Confusing | Simple |
| Steps | 3 steps | 2 steps |
| Error Prone | Yes (wrong otpId) | No |

---

## ✅ Updated API Documentation

### verifyOtp Mutation

**Input:**
- `code` (String, required) - The 6-digit code from email

**Output:**
- `user` - User object with profile
- `token` - JWT access token (valid 15 minutes)
- `refreshToken` - Refresh token (valid 30 days)

**Example:**
```graphql
mutation {
  verifyOtp(code: "123456") {
    user {
      id
      email
      status
    }
    token
    refreshToken
  }
}
```

**File Location:** 
- Schema: `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:16-19`
- Resolver: `lib/my_auth_system_web/graphql/resolvers/auth_resolver.ex:78-129`

---

## 🎓 Why This Is Better

### 1. **Simpler User Experience**
Users only need to copy the code from email - no technical knowledge required.

### 2. **Fewer Errors**
No more "Invalid OTP ID format" errors from wrong UUIDs.

### 3. **Faster Testing**
Developers can test faster without database queries.

### 4. **Better Security**
System automatically finds the right OTP - users can't accidentally use wrong OTP ID.

### 5. **Mobile-Friendly**
Easier to implement in mobile apps - just a text input for the code.

---

## 🚀 Quick Start

```bash
# 1. Start server
./load_env.sh

# 2. Open GraphiQL
open http://localhost:4000/api/graphiql

# 3. Register
# (paste register mutation from above)

# 4. Check email for code

# 5. Verify with just the code
# verifyOtp(code: "YOUR_CODE")

# 6. Done! You have your JWT token
```

---

## 📝 Summary

**What You Need to Remember:**
- ✅ OTP codes are 6 digits
- ✅ Valid for 1 hour
- ✅ Only need the code (no otpId!)
- ✅ Check your email after register/login
- ✅ Paste code into `verifyOtp` mutation

**That's it! Much simpler now! 🎉**

---

## 📚 Related Documentation

- **Complete API Reference:** `GRAPHQL_API_DOCUMENTATION.md`
- **GraphiQL Guide:** `README_GRAPHIQL.md`
- **Example Queries:** `priv/graphiql/example_queries.graphql`
- **Server Restart Guide:** `RESTART_SERVER_GUIDE.md`
