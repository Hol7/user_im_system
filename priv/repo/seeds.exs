# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     MyAuthSystem.Repo.insert!(%MyAuthSystem.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
# priv/repo/seeds.exs
alias MyAuthSystem.Repo
alias MyAuthSystem.Accounts.{User, Profile}
alias MyAuthSystem.Auth

# Helper pour créer un user
defp create_user!(attrs) do
  case Repo.insert(User.registration_changeset(%User{}, attrs)) do
    {:ok, user} ->
      # Créer le profile associé
      Repo.insert!(
        Profile.changeset(%Profile{user_id: user.id}, %{
          first_name: attrs[:first_name] || "Test",
          last_name: attrs[:last_name] || "User",
          phone: attrs[:phone] || "+22900000000",
          country: attrs[:country] || "Benin",
          city: attrs[:city] || "Cotonou",
          district: attrs[:district] || "Test District"
        })
      )

      # Marquer comme vérifié si admin
      if attrs[:role] == "admin" do
        user
        |> Ecto.Changeset.change(status: :active, email_verified_at: DateTime.utc_now())
        |> Repo.update!()
      end

      user

    {:error, changeset} ->
      IO.puts("❌ Erreur création user: #{inspect(changeset.errors)}")
      nil
  end
end

# === USERS DE TEST ===
IO.puts("🌱 Seeding test users...")

# User normal vérifié
create_user!(%{
  email: "user@example.com",
  password: "Password123!",
  password_confirmation: "Password123!",
  first_name: "Jean",
  last_name: "Dupont",
  phone: "+22997123456",
  country: "Benin",
  city: "Cotonou",
  district: "Akpakpa",
  role: "user"
})

# User non vérifié (pour tester le flow de validation)
create_user!(%{
  email: "pending@example.com",
  password: "Password123!",
  password_confirmation: "Password123!",
  first_name: "Marie",
  last_name: "K.",
  phone: "+22998765432",
  country: "Togo",
  city: "Lomé",
  role: "user"
  # status reste :pending_verification par défaut
})

# === ADMINS ===
IO.puts("👑 Creating admin accounts...")

# Super Admin
create_user!(%{
  email: "admin@myauthsystem.com",
  password: "SuperAdmin2026!",
  password_confirmation: "SuperAdmin2026!",
  first_name: "Admin",
  last_name: "Super",
  phone: "+22900000001",
  country: "Benin",
  city: "Cotonou",
  district: "Siège",
  role: "super_admin"
})

# Admin standard
create_user!(%{
  email: "support@myauthsystem.com",
  password: "Support2026!",
  password_confirmation: "Support2026!",
  first_name: "Support",
  last_name: "Team",
  phone: "+22900000002",
  country: "Benin",
  city: "Porto-Novo",
  role: "admin"
})

# === BULK TEST USERS (pour load testing) ===
IO.puts("📦 Creating 100 test users for scale testing...")

Enum.each(1..100, fn i ->
  create_user!(%{
    email: "testuser#{i}@example.com",
    password: "TestPass123!",
    password_confirmation: "TestPass123!",
    first_name: "Test#{i}",
    last_name: "User",
    phone: "+22990000#{String.pad_leading("#{i}", 4, "0")}",
    country: "Benin",
    city: "Cotonou",
    district: "Zone #{rem(i, 5) + 1}",
    role: "user"
  })
end)

IO.puts("✅ Seeding completed! Users created:")
IO.puts("   • user@example.com / Password123! (verified)")
IO.puts("   • pending@example.com / Password123! (pending verification)")
IO.puts("   • admin@myauthsystem.com / SuperAdmin2026! (super_admin)")
IO.puts("   • support@myauthsystem.com / Support2026! (admin)")
IO.puts("   • 100 test users (testuser1@example.com ... testuser100@example.com)")
