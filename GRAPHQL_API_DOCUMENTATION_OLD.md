# GraphQL API Complete Documentation

## 📋 Table of Contents
1. [Public User Operations](#public-user-operations)
2. [Protected User Operations](#protected-user-operations)
3. [Admin Operations](#admin-operations)
4. [Complete Authentication Flow](#complete-authentication-flow)
5. [OTP Verification Explained](#otp-verification-explained)

---

## 🔓 Public User Operations (No Authentication Required)

### 1. Register New Account

**Mutation:** `register`

**Purpose:** Create a new user account and send verification email with 6-digit OTP code

**GraphQL Query:**
```graphql
mutation {
  register(input: {
    email: "papesonnnn@yopmail.com"
    password: "SecurePass123!"
    passwordConfirmation: "SecurePass123!"
    firstName: "Pape"
    lastName: "Sonn"
    phone: "+22997123456"
    country: "Benin"
    city: "Cotonou"
    district: "Akpakpa"
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

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { register(input: { email: \"papesonnnn@yopmail.com\", password: \"SecurePass123!\", passwordConfirmation: \"SecurePass123!\", firstName: \"Pape\", lastName: \"Sonn\", phone: \"+22997123456\", country: \"Benin\", city: \"Cotonou\", district: \"Akpakpa\" }) { user { id email status } message } }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "register": {
      "user": {
        "id": "75fc5414-face-493c-85c5-2ca23e4c027e",
        "email": "papesonnnn@yopmail.com",
        "status": "PENDING_VERIFICATION"
      },
      "message": "Verification email sent"
    }
  }
}
```

**What Happens:**
1. User account created with status `PENDING_VERIFICATION`
2. User profile created with your information
3. 6-digit OTP code generated (e.g., "973456")
4. OTP stored in database with `email_verification` purpose
5. Email sent to your address with the OTP code

**File Location:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:6-15`

---

### 2. Verify Email with OTP

**Mutation:** `verifyOtp`

**Purpose:** Verify your email address using the 6-digit code from email

**✅ SIMPLIFIED:** 
- The OTP code is **6 digits** (e.g., "123456")
- You **ONLY need the code** from your email - no database query required!
- After verification, you get JWT tokens to access protected routes

**GraphQL Query:**
```graphql
mutation {
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

**💡 No Database Query Needed!**
Just check your email for the 6-digit code and paste it into the mutation. The system automatically finds the matching OTP.

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { verifyOtp(code:\"123456\") { user { id email status } token refreshToken } }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "verifyOtp": {
      "user": {
        "id": "75fc5414-face-493c-85c5-2ca23e4c027e",
        "email": "papesonnnn@yopmail.com",
        "status": "ACTIVE"
      },
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

**What Happens:**
1. System searches all unused, non-expired OTPs
2. Finds the OTP that matches your code (using Argon2 verification)
3. Checks OTP hasn't expired (valid for **1 hour**)
4. Generates JWT access token (valid 15 minutes)
5. Generates refresh token (valid 30 days)
6. Marks OTP as used
7. Updates user status to `ACTIVE`
8. Logs the login action

**File Location:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:16-19`
**Resolver:** `lib/my_auth_system_web/graphql/resolvers/auth_resolver.ex:83-129`

---

### 3. Login (2-Step Process)

**Mutation:** `login`

**Purpose:** Login with email/password and receive OTP code via email

**GraphQL Query:**
```graphql
mutation {
  login(
    email: "papesonnnn@yopmail.com"
    password: "SecurePass123!"
  ) {
    message
    otpId
  }
}
```

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { login(email:\"papesonnnn@yopmail.com\", password:\"SecurePass123!\") { message otpId } }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "login": {
      "message": "OTP sent to your email",
      "otpId": "a6763c02-07a9-442b-aab6-6d35df928a56"
    }
  }
}
```

**What Happens:**
1. System verifies email and password
2. Checks user status is `active` or `pending_verification`
3. Generates 6-digit OTP code
4. Sends OTP via email
5. Returns `otpId` for next step

**Next Step:** Use the `otpId` and the code from your email with `verifyOtp` mutation (same as step 2)

**File Location:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:24-28`

---

### 4. Request Password Reset

**Mutation:** `requestPasswordReset`

**Purpose:** Request a password reset OTP code via email

**GraphQL Query:**
```graphql
mutation {
  requestPasswordReset(email: "papesonnnn@yopmail.com") {
    message
  }
}
```

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { requestPasswordReset(email:\"papesonnnn@yopmail.com\") { message } }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "requestPasswordReset": {
      "message": "If an account exists for papesonnnn@yopmail.com, you will receive a reset code shortly."
    }
  }
}
```

**What Happens:**
1. System checks if user exists
2. Generates 6-digit OTP with `password_reset` purpose
3. Sends OTP via email
4. Returns generic message (security best practice)

**File Location:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:30-32`

---

### 5. Reset Password with OTP

**Mutation:** `resetPassword`

**Purpose:** Reset password using OTP code from email

**GraphQL Query:**
```graphql
mutation {
  resetPassword(
    otpId: "get-from-database-or-email"
    code: "123456"
    newPassword: "NewSecurePass123!"
    newPasswordConfirmation: "NewSecurePass123!"
  ) {
    message
  }
}
```

**How to Get OTP ID:**
```bash
psql -U bititi -d my_auth_system_dev -c "SELECT o.id FROM otps o JOIN users u ON u.id = o.user_id WHERE u.email = 'papesonnnn@yopmail.com' AND o.purpose = 'password_reset' AND o.used = false ORDER BY o.inserted_at DESC LIMIT 1;"
```

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { resetPassword(otpId:\"otp-id-here\", code:\"123456\", newPassword:\"NewPass123!\", newPasswordConfirmation:\"NewPass123!\") { message } }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "resetPassword": {
      "message": "Password successfully reset. Please login with your new password."
    }
  }
}
```

**What Happens:**
1. Verifies OTP code
2. Checks passwords match
3. Updates user password
4. Marks OTP as used
5. Revokes all existing refresh tokens
6. Logs password reset action

**File Location:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:34-40`

---

### 6. Refresh Access Token

**Mutation:** `refreshToken`

**Purpose:** Get new access token using refresh token

**GraphQL Query:**
```graphql
mutation {
  refreshToken(refreshToken: "your-refresh-token-here") {
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

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { refreshToken(refreshToken:\"eyJhbGci...\") { token refreshToken message } }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "refreshToken": {
      "user": {
        "id": "75fc5414-face-493c-85c5-2ca23e4c027e",
        "email": "papesonnnn@yopmail.com"
      },
      "token": "new-access-token",
      "refreshToken": "new-refresh-token",
      "message": "Token refreshed"
    }
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/public_auth_mutations.ex:42-48`

---

### 7. Health Check

**Query:** `health`

**Purpose:** Check if API is running

**GraphQL Query:**
```graphql
query {
  health
}
```

**cURL Example:**
```bash
curl -H "Content-Type: application/json" \
  -d '{"query":"{ health }"}' \
  http://localhost:4000/api/graphql
```

**Expected Response:**
```json
{
  "data": {
    "health": "OK"
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/schema.ex:18-20`

---

## 🔒 Protected User Operations (Requires JWT Token)

**How to Use JWT Token:**

Add the token to the `Authorization` header:
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -d '{"query":"{ me { id email } }"}' \
  http://localhost:4000/api/graphql
```

### 8. Get Current User Profile

**Query:** `me`

**Purpose:** Get authenticated user's profile information

**GraphQL Query:**
```graphql
query {
  me {
    id
    email
    role
    status
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

**Expected Response:**
```json
{
  "data": {
    "me": {
      "id": "75fc5414-face-493c-85c5-2ca23e4c027e",
      "email": "papesonnnn@yopmail.com",
      "role": "USER",
      "status": "ACTIVE",
      "profile": {
        "firstName": "Pape",
        "lastName": "Sonn",
        "phone": "+22997123456",
        "country": "Benin",
        "city": "Cotonou",
        "district": "Akpakpa",
        "avatarUrl": null
      }
    }
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/user_queries.ex:4-7`

---

### 9. Update Profile

**Mutation:** `updateProfile`

**Purpose:** Update user profile information

**GraphQL Query:**
```graphql
mutation {
  updateProfile(input: {
    firstName: "Pape Updated"
    lastName: "Sonn Updated"
    phone: "+22997654321"
    country: "Benin"
    city: "Porto-Novo"
    district: "Centre"
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

**File Location:** `lib/my_auth_system_web/graphql/types/user_mutations.ex:4-7`

---

### 10. Request Account Deletion

**Mutation:** `requestAccountDeletion`

**Purpose:** Request account deletion (requires admin approval)

**GraphQL Query:**
```graphql
mutation {
  requestAccountDeletion {
    message
  }
}
```

**Expected Response:**
```json
{
  "data": {
    "requestAccountDeletion": {
      "message": "Account deletion requested. An admin will review your request."
    }
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/user_mutations.ex:9-11`

---

## 👨‍💼 Admin Operations (Requires Admin/Super Admin Role)

### 11. List All Users (Admin)

**Query:** `adminUsers`

**Purpose:** List users with filtering and pagination

**GraphQL Query:**
```graphql
query {
  adminUsers(
    status: ACTIVE
    role: USER
    search: "pape"
    sortBy: INSERTED_AT
    sortOrder: DESC
    first: 10
  ) {
    id
    email
    role
    status
    profile {
      firstName
      lastName
    }
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/admin_queries.ex:7-17`

---

### 12. Create User (Admin)

**Mutation:** `adminCreateUser`

**Purpose:** Admin creates a new user account

**GraphQL Query:**
```graphql
mutation {
  adminCreateUser(input: {
    email: "newuser@example.com"
    password: "SecurePass123!"
    passwordConfirmation: "SecurePass123!"
    firstName: "New"
    lastName: "User"
    phone: "+22912345678"
    country: "Benin"
    city: "Cotonou"
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

**File Location:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:6-10`

---

### 13. Update User (Admin)

**Mutation:** `adminUpdateUser`

**Purpose:** Admin updates user information

**GraphQL Query:**
```graphql
mutation {
  adminUpdateUser(
    userId: "user-id-here"
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

**File Location:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:12-17`

---

### 14. Delete User (Admin)

**Mutation:** `adminDeleteUser`

**Purpose:** Admin permanently deletes a user

**GraphQL Query:**
```graphql
mutation {
  adminDeleteUser(userId: "user-id-here") {
    message
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:19-22`

---

### 15. Validate User (Admin)

**Mutation:** `adminValidateUser`

**Purpose:** Admin manually validates/activates a user

**GraphQL Query:**
```graphql
mutation {
  adminValidateUser(userId: "user-id-here") {
    user {
      id
      email
      status
    }
    message
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:24-28`

---

### 16. Process Deletion Request (Admin)

**Mutation:** `adminProcessDeletionRequest`

**Purpose:** Admin approves or rejects account deletion requests

**GraphQL Query:**
```graphql
mutation {
  adminProcessDeletionRequest(
    userId: "user-id-here"
    action: APPROVE
  ) {
    message
  }
}
```

**Actions:** `APPROVE` or `REJECT`

**File Location:** `lib/my_auth_system_web/graphql/types/admin_mutations.ex:30-35`

---

### 17. List Deletion Requests (Admin)

**Query:** `adminDeletionRequests`

**Purpose:** Get all pending deletion requests

**GraphQL Query:**
```graphql
query {
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

**File Location:** `lib/my_auth_system_web/graphql/types/admin_queries.ex:19-21`

---

### 18. List Audit Logs (Admin)

**Query:** `adminAuditLogs`

**Purpose:** View system audit logs

**GraphQL Query:**
```graphql
query {
  adminAuditLogs(
    userId: "optional-user-id"
    action: "LOGIN_SUCCESS"
    limit: 50
  ) {
    id
    userId
    action
    metadata
    insertedAt
  }
}
```

**File Location:** `lib/my_auth_system_web/graphql/types/admin_queries.ex:23-28`

---

## 🔄 Complete Authentication Flow

### Flow 1: New User Registration → Email Verification → Login

```bash
# Step 1: Register
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { register(input: { email: \"papesonnnn@yopmail.com\", password: \"SecurePass123!\", passwordConfirmation: \"SecurePass123!\", firstName: \"Pape\", lastName: \"Sonn\", phone: \"+22997123456\", country: \"Benin\", city: \"Cotonou\", district: \"Akpakpa\" }) { user { id email status } message } }"}' \
  http://localhost:4000/api/graphql

# Response: Check your email for 6-digit code (e.g., "973456")

# Step 2: Get OTP ID from database
psql -U bititi -d my_auth_system_dev -c "SELECT o.id FROM otps o JOIN users u ON u.id = o.user_id WHERE u.email = 'papesonnnn@yopmail.com' AND o.purpose = 'email_verification' AND o.used = false ORDER BY o.inserted_at DESC LIMIT 1;"

# Step 3: Verify email with OTP
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { verifyOtp(otpId:\"YOUR_OTP_ID\", code:\"973456\") { user { id email status } token refreshToken } }"}' \
  http://localhost:4000/api/graphql

# Response: You get JWT token and refreshToken
# Save the token for authenticated requests!
```

### Flow 2: Existing User Login

```bash
# Step 1: Login with email/password
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { login(email:\"papesonnnn@yopmail.com\", password:\"SecurePass123!\") { message otpId } }"}' \
  http://localhost:4000/api/graphql

# Response: otpId returned + email sent with 6-digit code

# Step 2: Verify OTP (use otpId from response and code from email)
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { verifyOtp(otpId:\"OTP_ID_FROM_STEP1\", code:\"CODE_FROM_EMAIL\") { user { id email status } token refreshToken } }"}' \
  http://localhost:4000/api/graphql

# Response: JWT token and refreshToken
```

### Flow 3: Password Reset

```bash
# Step 1: Request password reset
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { requestPasswordReset(email:\"papesonnnn@yopmail.com\") { message } }"}' \
  http://localhost:4000/api/graphql

# Step 2: Get OTP ID from database
psql -U bititi -d my_auth_system_dev -c "SELECT o.id FROM otps o JOIN users u ON u.id = o.user_id WHERE u.email = 'papesonnnn@yopmail.com' AND o.purpose = 'password_reset' AND o.used = false ORDER BY o.inserted_at DESC LIMIT 1;"

# Step 3: Reset password with OTP
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { resetPassword(otpId:\"YOUR_OTP_ID\", code:\"CODE_FROM_EMAIL\", newPassword:\"NewPass123!\", newPasswordConfirmation:\"NewPass123!\") { message } }"}' \
  http://localhost:4000/api/graphql

# Step 4: Login with new password (see Flow 2)
```

---

## 🔐 OTP Verification Explained

### What is OTP?

**OTP = One-Time Password** - A 6-digit code sent via email for security verification.

### OTP Code Format

- **Length:** 6 digits (e.g., "973456")
- **Validity:** 5 minutes from generation
- **Single Use:** Can only be used once

### OTP Purposes

1. **`email_verification`** - Verify email after registration
2. **`login`** - Two-factor authentication for login
3. **`password_reset`** - Verify identity for password reset

### How OTP Works

1. **Generation:** System creates random 6-digit code
2. **Storage:** Code is hashed and stored in database with:
   - `user_id` - Which user it belongs to
   - `purpose` - What it's for (email_verification, login, password_reset)
   - `expires_at` - When it expires (5 minutes)
   - `used` - Whether it's been used (false initially)
3. **Email:** Plain code sent to user's email
4. **Verification:** User provides code + otpId
5. **Validation:** System checks:
   - OTP exists and belongs to user
   - Code matches (using Argon2 hash comparison)
   - Not expired
   - Not already used
6. **Success:** OTP marked as used, action completed

### Why You Need Both otpId AND code

- **`otpId`** - Identifies WHICH OTP record in database
- **`code`** - The actual 6-digit secret from email

Think of it like:
- `otpId` = Your locker number
- `code` = Your locker combination

### Current Issue: otpId Not Returned

**Problem:** The `register` and `login` mutations don't return the `otpId` in the response.

**Workaround:** Query database to get it:
```bash
psql -U bititi -d my_auth_system_dev -c "SELECT o.id, o.purpose FROM otps o JOIN users u ON u.id = o.user_id WHERE u.email = 'YOUR_EMAIL' AND o.used = false ORDER BY o.inserted_at DESC LIMIT 1;"
```

**TODO:** Update mutations to return `otpId` in response.

---

## 📁 File Structure Reference

```
lib/my_auth_system_web/graphql/
├── schema.ex                          # Main schema, imports all types
├── types/
│   ├── common_types.ex               # Shared enums (UserRole, UserStatus)
│   ├── user.ex                       # User object type
│   ├── profile.ex                    # Profile object type
│   ├── public_auth_mutations.ex      # Public auth mutations (register, login, etc.)
│   ├── user_mutations.ex             # Protected user mutations
│   ├── user_queries.ex               # Protected user queries (me)
│   ├── admin_mutations.ex            # Admin mutations
│   └── admin_queries.ex              # Admin queries
├── resolvers/
│   ├── auth_resolver.ex              # Handles auth mutations
│   ├── user_resolver.ex              # Handles user mutations/queries
│   └── admin_resolver.ex             # Handles admin operations
└── middleware/
    └── require_role.ex               # Role-based access control
```

---

## 🎯 Quick Reference

### User Side Operations (18 total)

**Public (7):**
1. register
2. verifyOtp
3. login
4. requestPasswordReset
5. resetPassword
6. refreshToken
7. health

**Protected (3):**
8. me (query)
9. updateProfile
10. requestAccountDeletion

### Admin Side Operations (8 total)

11. adminUsers (query)
12. adminCreateUser
13. adminUpdateUser
14. adminDeleteUser
15. adminValidateUser
16. adminProcessDeletionRequest
17. adminDeletionRequests (query)
18. adminAuditLogs (query)

---

## 🚀 Testing Your Account Right Now

Based on your email with code **973**, here's how to verify:

```bash
# Get your OTP ID
psql -U bititi -d my_auth_system_dev -c "SELECT o.id FROM otps o JOIN users u ON u.id = o.user_id WHERE u.email = 'papesonnnn@yopmail.com' AND o.purpose = 'email_verification' AND o.used = false ORDER BY o.inserted_at DESC LIMIT 1;"

# Then verify (replace OTP_ID with result from above)
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { verifyOtp(otpId:\"OTP_ID_HERE\", code:\"973\") { user { id email status } token refreshToken } }"}' \
  http://localhost:4000/api/graphql
```

**Note:** Your code might be 6 digits (e.g., "973456"), not just "973". Check your email for the complete code!
