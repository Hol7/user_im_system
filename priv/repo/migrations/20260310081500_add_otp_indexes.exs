defmodule MyAuthSystem.Repo.Migrations.AddOtpIndexes do
  use Ecto.Migration

  def change do
    # Composite index for efficient OTP lookup by user
    create index(:otps, [:user_id, :purpose, :used, :expires_at],
             name: :otps_user_purpose_lookup_idx)

    # Index for cleanup queries
    create index(:otps, [:used, :expires_at], name: :otps_cleanup_idx)
  end
end
