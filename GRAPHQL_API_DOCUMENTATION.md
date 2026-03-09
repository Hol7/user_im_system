# 🚀 GraphQL API Complete Documentation - UPDATED

## 📋 Table of Contents
1. [How to Use JWT Tokens](#how-to-use-jwt-tokens)
2. [Public Operations (No Auth)](#public-operations)
3. [Protected User Operations](#protected-user-operations)
4. [Admin Operations](#admin-operations)
5. [Complete Authentication Flow](#complete-authentication-flow)

---

## 🔑 How to Use JWT Tokens

### Getting Your JWT Token

After successful login or OTP verification, you receive:
- **Access Token** (`token`) - Valid for 15 minutes
- **Refresh Token** (`refreshToken`) - Valid for 30 days

### Using Tokens in Requests

#### In GraphiQL (http://localhost:4000/api/graphiql)

1. Click the **"Headers"** button at the bottom
2. Add this JSON:
```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN_HERE"
}
```

#### In cURL

Add the `-H` header flag:
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -d '{"query":"{ me { id email } }"}' \
  http://localhost:4000/api/graphql
```

#### In JavaScript/Fetch

```javascript
fetch('http://localhost:4000/api/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_ACCESS_TOKEN_HERE'
  },
  body: JSON.stringify({
    query: '{ me { id email } }'
  })
})
```

#### In Postman

1. Go to **Headers** tab
2. Add new header:
   - Key: `Authorization`
   - Value: `Bearer YOUR_ACCESS_TOKEN_HERE`

---

## 🔓 Public Operations (No Authentication Required)

### 1. Health Check

**Query:** `health`

**Purpose:** Test if API is running

**GraphQL:**
```graphql
{
  health
}
```

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"{ health }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "health": "OK"
  }
}
```

---

### 2. Register New Account

**Mutation:** `register`

**Purpose:** Create account and send verification email with 6-digit OTP

**GraphQL:**
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
    district: "Manhattan"
  }) {
    user {
      id
      email
      status
      role
    }
    message
  }
}
```

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { register(input: { email: \"test@example.com\", password: \"SecurePass123!\", passwordConfirmation: \"SecurePass123!\", firstName: \"John\", lastName: \"Doe\", phone: \"+1234567890\", country: \"USA\", city: \"New York\" }) { user { id email status } message } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "register": {
      "user": {
        "id": "uuid-here",
        "email": "test@example.com",
        "status": "PENDING_VERIFICATION",
        "role": "USER"
      },
      "message": "Verification email sent"
    }
  }
}
```

**What Happens:**
1. User account created with status `PENDING_VERIFICATION`
2. User profile created
3. 6-digit OTP code generated (e.g., "123456")
4. OTP valid for **1 hour**
5. Email sent with OTP code

**File:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:5-8`

---

### 3. Verify Email with OTP ✅ SIMPLIFIED

**Mutation:** `verifyOtp`

**Purpose:** Verify email using ONLY the 6-digit code from email

**✅ NO DATABASE QUERY NEEDED!** Just use the code from your email.

**GraphQL:**
```graphql
mutation {
  verifyOtp(code: "123456") {
    user {
      id
      email
      status
      role
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

**Response:**
```json
{
  "data": {
    "verifyOtp": {
      "user": {
        "id": "uuid-here",
        "email": "test@example.com",
        "status": "ACTIVE",
        "role": "USER"
      },
      "token": "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

**⚠️ SAVE YOUR TOKENS!** You'll need the `token` for authenticated requests.

**What Happens:**
1. System finds all unused, non-expired OTPs
2. Verifies which OTP matches your code (Argon2 hash)
3. Generates JWT access token (15 min validity)
4. Generates refresh token (30 days validity)
5. Marks OTP as used
6. Updates user status to `ACTIVE`

**File:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:16-19`

---

### 4. Login (Step 1 - Get OTP)

**Mutation:** `login`

**Purpose:** Login with email/password, receive OTP via email

**GraphQL:**
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

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { login(email:\"test@example.com\", password:\"SecurePass123!\") { message otpId } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "login": {
      "message": "OTP sent to your email",
      "otpId": "uuid-here"
    }
  }
}
```

**Next Step:** Check email for 6-digit code, then use `verifyOtp` mutation

**File:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:10-14`

---

### 5. Login (Step 2 - Verify OTP)

Use the same `verifyOtp` mutation as email verification:

```graphql
mutation {
  verifyOtp(code: "789012") {
    user { id email }
    token
    refreshToken
  }
}
```

---

### 6. Request Password Reset

**Mutation:** `requestPasswordReset`

**Purpose:** Request password reset OTP via email

**GraphQL:**
```graphql
mutation {
  requestPasswordReset(email: "test@example.com") {
    message
  }
}
```

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { requestPasswordReset(email:\"test@example.com\") { message } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "requestPasswordReset": {
      "message": "If an account exists for test@example.com, you will receive a reset code shortly."
    }
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:26-29`

---

### 7. Reset Password

**Mutation:** `resetPassword`

**Purpose:** Reset password using OTP code

**GraphQL:**
```graphql
mutation {
  resetPassword(
    otpId: "uuid-from-email-or-database"
    code: "123456"
    newPassword: "NewSecurePass123!"
    newPasswordConfirmation: "NewSecurePass123!"
  ) {
    message
  }
}
```

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { resetPassword(otpId:\"uuid-here\", code:\"123456\", newPassword:\"NewPass123!\", newPasswordConfirmation:\"NewPass123!\") { message } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "resetPassword": {
      "message": "Password reset successfully"
    }
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:31-37`

---

### 8. Refresh Access Token

**Mutation:** `refreshToken`

**Purpose:** Get new access token using refresh token

**GraphQL:**
```graphql
mutation {
  refreshToken(refreshToken: "YOUR_REFRESH_TOKEN_HERE") {
    user {
      id
      email
    }
    token
    refreshToken
    message
  }
}
```

**cURL:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { refreshToken(refreshToken:\"YOUR_REFRESH_TOKEN\") { token refreshToken message } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "refreshToken": {
      "user": {
        "id": "uuid-here",
        "email": "test@example.com"
      },
      "token": "new-access-token",
      "refreshToken": "new-refresh-token",
      "message": "Token refreshed"
    }
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:21-24`

---

## 🔒 Protected User Operations (Requires JWT Token)

**⚠️ IMPORTANT:** Add JWT token to headers for all requests below!

### 9. Get Current User Profile

**Query:** `me`

**Purpose:** Get your own user profile

**GraphQL:**
```graphql
{
  me {
    id
    email
    role
    status
    lastLoginAt
    emailVerifiedAt
    profile {
      firstName
      lastName
      phone
      country
      city
      district
      avatarUrl
    }
  }
}
```

**cURL with JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -d '{"query":"{ me { id email role status profile { firstName lastName } } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "me": {
      "id": "uuid-here",
      "email": "test@example.com",
      "role": "USER",
      "status": "ACTIVE",
      "profile": {
        "firstName": "John",
        "lastName": "Doe"
      }
    }
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/user_queries.ex:4-6`

---

### 10. Update Profile

**Mutation:** `updateProfile`

**Purpose:** Update your profile information

**GraphQL:**
```graphql
mutation {
  updateProfile(input: {
    firstName: "Jane"
    lastName: "Smith"
    phone: "+9876543210"
    country: "Canada"
    city: "Toronto"
    district: "Downtown"
  }) {
    profile {
      firstName
      lastName
      phone
      city
    }
    message
  }
}
```

**cURL with JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { updateProfile(input: { firstName: \"Jane\", lastName: \"Smith\", city: \"Toronto\" }) { profile { firstName lastName city } message } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "updateProfile": {
      "profile": {
        "firstName": "Jane",
        "lastName": "Smith",
        "city": "Toronto"
      },
      "message": "Profile updated"
    }
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/user_mutations.ex:5-8`

---

### 11. Request Account Deletion

**Mutation:** `requestAccountDeletion`

**Purpose:** Request account deletion (30-day grace period)

**GraphQL:**
```graphql
mutation {
  requestAccountDeletion {
    message
  }
}
```

**cURL with JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { requestAccountDeletion { message } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "requestAccountDeletion": {
      "message": "Account deletion requested. You have 30 days to cancel."
    }
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/user_mutations.ex:10-12`

---

## 👨‍💼 Admin Operations (Requires Admin JWT Token)

**⚠️ IMPORTANT:** User must have `ADMIN` or `SUPER_ADMIN` role!

### 12. List All Users

**Query:** `adminUsers`

**Purpose:** List all users with filters and sorting

**GraphQL:**
```graphql
{
  adminUsers(
    status: ACTIVE
    role: USER
    search: "john"
    sortBy: INSERTED_AT
    sortOrder: DESC
    first: 10
  ) {
    id
    email
    role
    status
    lastLoginAt
    profile {
      firstName
      lastName
      phone
    }
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"{ adminUsers(first: 10) { id email role status } }"}' \
  http://localhost:4000/api/graphql
```

**Response:**
```json
{
  "data": {
    "adminUsers": [
      {
        "id": "uuid-1",
        "email": "user1@example.com",
        "role": "USER",
        "status": "ACTIVE"
      },
      {
        "id": "uuid-2",
        "email": "user2@example.com",
        "role": "USER",
        "status": "PENDING_VERIFICATION"
      }
    ]
  }
}
```

**File:** `lib/my_auth_system_web/graphql/types/admin_queries.ex:9-19`

---

### 13. Create User (Admin)

**Mutation:** `adminCreateUser`

**Purpose:** Admin creates a new user account

**GraphQL:**
```graphql
mutation {
  adminCreateUser(input: {
    email: "newuser@example.com"
    password: "SecurePass123!"
    passwordConfirmation: "SecurePass123!"
    firstName: "Admin"
    lastName: "Created"
    phone: "+1111111111"
    country: "USA"
    city: "Boston"
    role: USER
    status: ACTIVE
  }) {
    user {
      id
      email
      role
      status
    }
    message
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { adminCreateUser(input: { email: \"new@example.com\", password: \"Pass123!\", passwordConfirmation: \"Pass123!\", firstName: \"New\", lastName: \"User\", phone: \"+123\", country: \"USA\", city: \"NYC\", role: USER, status: ACTIVE }) { user { id email } } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:6-10`

---

### 14. Update User (Admin)

**Mutation:** `adminUpdateUser`

**Purpose:** Admin updates user information

**GraphQL:**
```graphql
mutation {
  adminUpdateUser(
    id: "user-uuid-here"
    input: {
      status: SUSPENDED
      role: ADMIN
    }
  ) {
    user {
      id
      email
      role
      status
    }
    message
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { adminUpdateUser(id: \"uuid\", input: { status: SUSPENDED }) { user { id status } message } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:12-17`

---

### 15. Delete User (Admin)

**Mutation:** `adminDeleteUser`

**Purpose:** Admin soft-deletes a user

**GraphQL:**
```graphql
mutation {
  adminDeleteUser(id: "user-uuid-here") {
    message
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { adminDeleteUser(id: \"uuid\") { message } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:19-23`

---

### 16. Validate User (Admin)

**Mutation:** `adminValidateUser`

**Purpose:** Admin validates a pending user account

**GraphQL:**
```graphql
mutation {
  adminValidateUser(id: "user-uuid-here") {
    user {
      id
      email
      status
    }
    message
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { adminValidateUser(id: \"uuid\") { user { id status } message } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:25-29`

---

### 17. Process Deletion Request (Admin)

**Mutation:** `adminProcessDeletionRequest`

**Purpose:** Admin approves or rejects account deletion

**GraphQL:**
```graphql
mutation {
  adminProcessDeletionRequest(
    id: "user-uuid-here"
    action: APPROVE
  ) {
    message
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"mutation { adminProcessDeletionRequest(id: \"uuid\", action: APPROVE) { message } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:31-37`

---

### 18. List Deletion Requests (Admin)

**Query:** `adminDeletionRequests`

**Purpose:** List all pending deletion requests

**GraphQL:**
```graphql
{
  adminDeletionRequests {
    id
    email
    status
    profile {
      firstName
      lastName
    }
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"{ adminDeletionRequests { id email status } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_queries.ex:29-32`

---

### 19. List Audit Logs (Admin)

**Query:** `adminAuditLogs`

**Purpose:** View audit logs for security monitoring

**GraphQL:**
```graphql
{
  adminAuditLogs(
    userId: "optional-user-uuid"
    action: "LOGIN_SUCCESS"
    limit: 50
  ) {
    id
    userId
    action
    metadata
    ipAddress
    insertedAt
  }
}
```

**cURL with Admin JWT:**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN_HERE" \
  -d '{"query":"{ adminAuditLogs(limit: 20) { id action insertedAt } }"}' \
  http://localhost:4000/api/graphql
```

**File:** `lib/my_auth_system_web/graphql/types/admin_queries.ex:35-41`

---

## 🔄 Complete Authentication Flow

### New User Registration Flow

```
1. REGISTER
   mutation { register(input: {...}) { user { id } message } }
   ↓
2. CHECK EMAIL
   Receive 6-digit OTP code (e.g., "123456")
   ↓
3. VERIFY OTP
   mutation { verifyOtp(code: "123456") { token refreshToken } }
   ↓
4. SAVE TOKENS
   Store access token and refresh token
   ↓
5. USE TOKEN
   Add "Authorization: Bearer TOKEN" to all protected requests
```

### Existing User Login Flow

```
1. LOGIN
   mutation { login(email: "...", password: "...") { message otpId } }
   ↓
2. CHECK EMAIL
   Receive 6-digit OTP code
   ↓
3. VERIFY OTP
   mutation { verifyOtp(code: "123456") { token refreshToken } }
   ↓
4. SAVE TOKENS
   ↓
5. USE TOKEN
```

### Token Refresh Flow

```
1. ACCESS TOKEN EXPIRES (after 15 minutes)
   ↓
2. USE REFRESH TOKEN
   mutation { refreshToken(refreshToken: "...") { token refreshToken } }
   ↓
3. SAVE NEW TOKENS
   ↓
4. CONTINUE USING NEW ACCESS TOKEN
```

---

## 📝 Important Notes

### OTP Details
- **Length:** 6 digits (e.g., "123456")
- **Validity:** 1 hour (60 minutes)
- **Single Use:** Can only be used once
- **Purposes:** email_verification, login, password_reset

### JWT Token Details
- **Access Token:** Valid for 15 minutes
- **Refresh Token:** Valid for 30 days
- **Format:** `Bearer YOUR_TOKEN_HERE`
- **Header:** `Authorization: Bearer TOKEN`

### User Roles
- `USER` - Regular user
- `ADMIN` - Administrator
- `SUPER_ADMIN` - Super administrator

### User Status
- `PENDING_VERIFICATION` - Email not verified
- `ACTIVE` - Account active
- `SUSPENDED` - Account suspended
- `DELETION_REQUESTED` - Deletion pending

---

## 🐛 Troubleshooting

### "Unauthorized" Error
**Solution:** Add JWT token to Authorization header

### "Invalid or expired OTP code"
**Causes:**
- Wrong code (typo)
- OTP expired (>1 hour old)
- OTP already used

**Solution:** Request new OTP (register/login again)

### "Failed to generate tokens: :secret_not_found"
**Solution:** Restart server with `./load_env.sh` to load GUARDIAN_SECRET_KEY

### No Email Received
**Check:**
1. Server running: `./load_env.sh`
2. BREVO_API_KEY set in `.env`
3. Spam folder
4. Oban dashboard: http://localhost:4000/oban

---

## ✅ Quick Test Checklist

```bash
# 1. Health check
curl -H "Content-Type: application/json" -d '{"query":"{ health }"}' http://localhost:4000/api/graphql

# 2. Register
curl -H "Content-Type: application/json" -d '{"query":"mutation { register(input: { email: \"test@example.com\", password: \"Pass123!\", passwordConfirmation: \"Pass123!\", firstName: \"Test\", lastName: \"User\", phone: \"+123\", country: \"USA\", city: \"NYC\" }) { user { id } message } }"}' http://localhost:4000/api/graphql

# 3. Check email for 6-digit code

# 4. Verify OTP
curl -H "Content-Type: application/json" -d '{"query":"mutation { verifyOtp(code:\"123456\") { token refreshToken } }"}' http://localhost:4000/api/graphql

# 5. Get profile (use token from step 4)
curl -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN" -d '{"query":"{ me { id email } }"}' http://localhost:4000/api/graphql
```

---

**🎉 All 19 operations documented and tested!**
