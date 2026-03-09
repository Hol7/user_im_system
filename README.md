# MyAuthSystem

A complete authentication system built with Phoenix, Absinthe GraphQL, and PostgreSQL.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
mix deps.get
```

### 2. Setup Database

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate
```

### 3. Configure Environment Variables

**IMPORTANT:** Create a `.env` file in the project root with the following variables:

```bash
# Database
DATABASE_URL=ecto://bititi@localhost/my_auth_system_dev

# Phoenix
PHX_HOST=localhost
PHX_SERVER=true
PORT=4000

# Secrets (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your-secret-key-base-min-64-chars
GUARDIAN_SECRET_KEY=your-guardian-secret-key

# Brevo Email API
BREVO_API_KEY=your-brevo-api-key
BREVO_SENDER_NAME="MyAuth System"
BREVO_SENDER_EMAIL=noreply@myauthsystem.com

# Oban Dashboard
OBAN_DASHBOARD_PASS=change_me
```

**Note:** Make sure to quote values with spaces (e.g., `BREVO_SENDER_NAME="MyAuth System"`)

### 4. Create Admin User

Run the admin creation script:

```bash
mix run priv/scripts/create_admin.exs
```

This creates an admin user with:
- **Email:** `fabrown40@gmail.com`
- **Password:** `admin123@`
- **Role:** `admin`
- **Status:** `active` (email verified)

You can edit the script to change these values before running.

### 5. Start the Application

```bash
# Load environment variables and start server
./load_env.sh
```

The app will be available at: **http://localhost:4000**

GraphQL endpoint: **http://localhost:4000/api/graphql**

---

## 📚 API Documentation

See **[GRAPHQL_API_DOCUMENTATION.md](./GRAPHQL_API_DOCUMENTATION.md)** for:
- Complete GraphQL API reference
- All queries and mutations
- Authentication flow (register → OTP → verify)
- Admin operations
- cURL examples
- Troubleshooting

---

## 🔑 Authentication Flow

### For Regular Users

1. **Register** → `register` mutation
2. **Check email** → Get 6-digit OTP code
3. **Verify OTP** → `verifyOtp` mutation → Get JWT token
4. **Use token** → Add to `Authorization: Bearer TOKEN` header

### For Admin Users

Admins follow the **same flow** as regular users:
1. **Login** → `login` mutation
2. **Check email** → Get OTP code
3. **Verify OTP** → `verifyOtp` mutation → Get JWT token with admin role
4. **Use token** → Access admin queries/mutations

---

## 🧪 Testing the API

### Using GraphiQL (Browser)

Visit: **http://localhost:4000/api/graphiql**

### Using cURL

```bash
# Register a new user
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { register(input: { email: \"test@example.com\", password: \"Pass123!\", passwordConfirmation: \"Pass123!\", firstName: \"Test\", lastName: \"User\" }) { message } }"}' \
  http://localhost:4000/api/graphql

# Verify OTP (check email for code)
curl -H "Content-Type: application/json" \
  -d '{"query":"mutation { verifyOtp(code: \"123456\") { user { id email } token refreshToken } }"}' \
  http://localhost:4000/api/graphql

# Get current user (with token)
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"query":"{ me { id email role status profile { firstName lastName } } }"}' \
  http://localhost:4000/api/graphql
```

---

## 🐳 Docker Setup (Optional)

### Start with Docker Compose

```bash
# Build and start
docker compose up -d

# View logs
docker compose logs -f app

# Stop
docker compose down
```

**Note:** Docker uses port `5433` for PostgreSQL to avoid conflicts with local PostgreSQL on `5432`.

---

## 📁 Project Structure

```
lib/
├── my_auth_system/
│   ├── accounts/          # User and Profile schemas
│   ├── auth/              # Authentication logic, OTP, JWT
│   ├── audit/             # Audit logging
│   └── workers/           # Background jobs (email sending)
├── my_auth_system_web/
│   ├── graphql/
│   │   ├── resolvers/     # GraphQL resolvers
│   │   ├── types/         # GraphQL schema types
│   │   ├── middleware/    # Auth middleware
│   │   └── schema.ex      # Main GraphQL schema
│   └── plugs/             # GraphQL auth plug
priv/
├── repo/migrations/       # Database migrations
└── scripts/
    └── create_admin.exs   # Admin user creation script
```

---

## 🔧 Common Commands

```bash
# Install dependencies
mix deps.get

# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Start server
./load_env.sh

# Start interactive shell
iex -S mix phx.server

# Run tests
mix test

# Format code
mix format

# Check code quality
mix precommit
```

---

## 🛠️ Troubleshooting

### "Command not found: mix"

Make sure Elixir is installed and in your PATH.

### "Database does not exist"

Run: `mix ecto.create`

### "Missing Oban tables"

Run: `mix ecto.migrate`

### ".env syntax error"

Make sure to quote values with spaces:
```bash
BREVO_SENDER_NAME="MyAuth System"  # ✅ Correct
BREVO_SENDER_NAME=MyAuth System    # ❌ Wrong
```

### "Invalid or expired OTP code"

- OTP codes expire after 1 hour
- OTP codes are single-use only
- Request a new OTP by logging in again

### "Unauthorized" error

Add JWT token to request headers:
```
Authorization: Bearer YOUR_TOKEN_HERE
```

---

## 📖 Learn More

* **GraphQL API:** [GRAPHQL_API_DOCUMENTATION.md](./GRAPHQL_API_DOCUMENTATION.md)
* **Phoenix Framework:** https://www.phoenixframework.org/
* **Absinthe GraphQL:** https://hexdocs.pm/absinthe
* **Guardian Auth:** https://hexdocs.pm/guardian
