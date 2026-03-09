# Script to create admin user
# Run with: mix run priv/scripts/create_admin.exs

alias MyAuthSystem.{Accounts, Repo}
alias MyAuthSystem.Accounts.{User, Profile}

# Admin user data
attrs = %{
  email: "fabrown40@gmail.com",
  password: "admin123@",
  password_confirmation: "admin123@",
  first_name: "Admin",
  last_name: "User",
  phone: "+1234567890",
  country: "USA",
  city: "New York"
}

# Create admin user (bypasses email verification)
user = (
  %User{}
  |> User.registration_changeset(attrs)
  |> Ecto.Changeset.put_change(:role, :admin)
  |> Ecto.Changeset.put_change(:status, :active)
  |> Ecto.Changeset.put_change(:email_verified_at, DateTime.utc_now() |> DateTime.truncate(:second))
  |> Repo.insert!()
)

# Create profile
{:ok, _profile} = Accounts.create_profile(user, attrs)

IO.puts("\n✅ Admin user created successfully!")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("Email: #{user.email}")
IO.puts("Password: admin123@")
IO.puts("Role: #{user.role}")
IO.puts("Status: #{user.status}")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
