# 🚀 How to Run MyAuthSystem

## Quick Start

```bash
# Set environment variables
export GUARDIAN_SECRET_KEY=QbL0Wads3TrGlyZk8EIxWH6SQ8L9UylFSGGUrVRYGjPD8S+gUqA4GfsHit7LYfSC
export SECRET_KEY_BASE=RPrP8yxBCcxwrY9cDLQFi5E7zj5ni7p5Xy5vNc/h/mXIFYul3trAaED307gQpA10
export DB_USERNAME=bititi
export DB_PASSWORD=""

# Start the server
mix phx.server
```

## Access Points

- **GraphiQL Playground**: http://localhost:4000/api/graphiql
- **Oban Dashboard**: http://localhost:4000/oban
- **Health Check**: http://localhost:4000/api/health

## Test Queries

### 1. Health Check
```bash
curl http://localhost:4000/api/health
```

### 2. Register a New User (GraphiQL)
```graphql
mutation {
  register(input: {
    email: "test@example.com"
    password: "SecurePass123!"
    passwordConfirmation: "SecurePass123!"
    firstName: "John"
    lastName: "Doe"
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

### 3. Login (Request OTP)
```graphql
mutation {
  login(email: "test@example.com", password: "SecurePass123!") {
    message
    otpId
  }
}
```

### 4. Verify OTP & Get JWT Token
```graphql
mutation {
  verifyOtp(otpId: "otp-uuid-here", code: "123456") {
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

## Environment Variables

All environment variables are stored in `.env` file:
- `GUARDIAN_SECRET_KEY` - JWT secret
- `SECRET_KEY_BASE` - Phoenix secret
- `DB_USERNAME` - PostgreSQL username (bititi)
- `DB_PASSWORD` - PostgreSQL password (empty for local)
- `BREVO_API_KEY` - Email service API key

## Database Commands

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Drop database (if needed)
mix ecto.drop

# Reset database
mix ecto.reset
```

## Notes

- The app uses **GraphQL** as the primary API (not REST)
- Authentication uses **JWT tokens** with Guardian
- **OTP-based 2FA** for login and password reset
- Background jobs handled by **Oban**
- Email notifications via **Brevo/SendinBlue**
