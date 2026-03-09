# Database Access Guide

This guide shows you how to view and query your PostgreSQL database data.

## Option 1: Using IEx (Interactive Elixir)

### Start IEx with your app loaded:
```bash
iex -S mix
```

### Common queries:

#### View all users:
```elixir
alias MyAuthSystem.Repo
alias MyAuthSystem.Accounts.User
alias MyAuthSystem.Accounts.Profile

# Get all users with their profiles preloaded
users = Repo.all(User) |> Repo.preload(:profile)
Enum.each(users, fn u -> 
  IO.inspect(%{
    id: u.id, 
    email: u.email, 
    status: u.status, 
    role: u.role,
    name: "#{u.profile.first_name} #{u.profile.last_name}"
  })
end)
```

#### View recent users:
```elixir
import Ecto.Query

User 
|> order_by(desc: :inserted_at) 
|> limit(10) 
|> Repo.all() 
|> Repo.preload(:profile)
|> Enum.each(fn u -> 
  IO.puts("#{u.email} - #{u.status} - Created: #{u.inserted_at}")
end)
```

#### View OTP codes (for testing):
```elixir
alias MyAuthSystem.Auth.Otp

Otp 
|> order_by(desc: :inserted_at) 
|> limit(5) 
|> Repo.all() 
|> Repo.preload(:user)
|> Enum.each(fn otp -> 
  IO.inspect(%{
    user_email: otp.user.email,
    purpose: otp.purpose,
    used: otp.used,
    expires_at: otp.expires_at,
    inserted_at: otp.inserted_at
  })
end)
```

#### View Oban jobs:
```elixir
alias Oban.Job

Job 
|> order_by(desc: :inserted_at) 
|> limit(10) 
|> Repo.all()
|> Enum.each(fn j -> 
  IO.inspect(%{
    id: j.id,
    queue: j.queue,
    state: j.state,
    worker: j.worker,
    attempt: j.attempt,
    args: j.args,
    errors: if(length(j.errors) > 0, do: List.first(j.errors)["error"], else: nil)
  })
end)
```

#### Count records:
```elixir
IO.puts("Total users: #{Repo.aggregate(User, :count, :id)}")
IO.puts("Active users: #{Repo.aggregate(from(u in User, where: u.status == :active), :count, :id)}")
IO.puts("Pending verification: #{Repo.aggregate(from(u in User, where: u.status == :pending_verification), :count, :id)}")
```

#### Find user by email:
```elixir
user = Repo.get_by(User, email: "test@example.com") |> Repo.preload(:profile)
IO.inspect(user)
```

#### Update user status manually:
```elixir
user = Repo.get_by(User, email: "test@example.com")
user 
|> Ecto.Changeset.change(%{status: :active, email_verified_at: DateTime.utc_now()}) 
|> Repo.update()
```

---

## Option 2: Using psql (PostgreSQL CLI)

### Connect to database:
```bash
psql -U bititi -d my_auth_system_dev
```

### Common SQL queries:

#### View all users:
```sql
SELECT id, email, status, role, inserted_at 
FROM users 
ORDER BY inserted_at DESC 
LIMIT 10;
```

#### View users with profiles:
```sql
SELECT 
  u.email, 
  u.status, 
  u.role,
  p.first_name, 
  p.last_name, 
  p.phone,
  u.inserted_at
FROM users u
LEFT JOIN profiles p ON p.user_id = u.id
ORDER BY u.inserted_at DESC;
```

#### View OTP codes:
```sql
SELECT 
  o.id,
  u.email,
  o.purpose,
  o.used,
  o.expires_at,
  o.inserted_at
FROM otps o
JOIN users u ON u.id = o.user_id
ORDER BY o.inserted_at DESC
LIMIT 10;
```

#### View Oban jobs:
```sql
SELECT 
  id,
  queue,
  state,
  worker,
  attempt,
  max_attempts,
  args,
  inserted_at,
  attempted_at
FROM oban_jobs
ORDER BY inserted_at DESC
LIMIT 10;
```

#### Count users by status:
```sql
SELECT status, COUNT(*) 
FROM users 
GROUP BY status;
```

---

## Option 3: Using a GUI Database Client

### Recommended tools:

1. **pgAdmin** (Free, cross-platform)
   - Download: https://www.pgadmin.org/download/
   - Connection details:
     - Host: localhost
     - Port: 5432
     - Database: my_auth_system_dev
     - Username: bititi
     - Password: (leave empty if no password)

2. **DBeaver** (Free, cross-platform)
   - Download: https://dbeaver.io/download/
   - Same connection details as above

3. **Postico** (macOS only, free version available)
   - Download: https://eggerapps.at/postico/
   - Same connection details as above

4. **TablePlus** (macOS/Windows, free trial)
   - Download: https://tableplus.com/
   - Same connection details as above

### Connection Settings:
- **Host:** localhost
- **Port:** 5432
- **Database:** my_auth_system_dev
- **Username:** bititi
- **Password:** (empty)
- **SSL Mode:** Disable (for local development)

---

## Option 4: Quick One-Liners

### From terminal (without entering IEx):

#### Count all users:
```bash
mix run -e 'alias MyAuthSystem.Repo; alias MyAuthSystem.Accounts.User; IO.puts("Total users: #{Repo.aggregate(User, :count, :id)}")'
```

#### List recent users:
```bash
mix run -e 'alias MyAuthSystem.Repo; alias MyAuthSystem.Accounts.User; import Ecto.Query; Repo.all(from u in User, order_by: [desc: u.inserted_at], limit: 5, preload: :profile) |> Enum.each(fn u -> IO.puts("#{u.email} - #{u.status}") end)'
```

#### View Oban job count:
```bash
mix run -e 'alias MyAuthSystem.Repo; alias Oban.Job; IO.puts("Total jobs: #{Repo.aggregate(Job, :count, :id)}")'
```

---

## Useful Database Commands

### Reset database (WARNING: Deletes all data):
```bash
mix ecto.reset
```

### Drop and recreate database:
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

### Run migrations:
```bash
mix ecto.migrate
```

### Rollback last migration:
```bash
mix ecto.rollback
```

### Check migration status:
```bash
mix ecto.migrations
```

---

## Tips

1. **Always preload associations** in IEx to avoid N+1 queries:
   ```elixir
   user = Repo.get(User, id) |> Repo.preload([:profile, :otps])
   ```

2. **Use `IO.inspect/2` with labels** for better debugging:
   ```elixir
   user |> IO.inspect(label: "User data")
   ```

3. **Format output** for better readability:
   ```elixir
   users |> Enum.map(&Map.take(&1, [:id, :email, :status])) |> IO.inspect()
   ```

4. **Check Oban dashboard** at http://localhost:4000/oban for visual job monitoring
