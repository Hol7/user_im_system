defmodule MyAuthSystem.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Case-insensitive email search (critical for admin search)
    create_if_not_exists index(:users, ["lower(email)"], name: :users_email_lower_idx)

    # Composite index for filtered user listing (status + role + time)
    create_if_not_exists index(:users, [:status, :role, :inserted_at],
      name: :users_status_role_time_idx
    )

    # Composite index for user activity queries
    create_if_not_exists index(:users, [:last_login_at, :status],
      name: :users_last_login_status_idx
    )

    # Composite index for audit log queries (user + action + time)
    create_if_not_exists index(:audit_logs, [:user_id, :action, :inserted_at],
      name: :audit_logs_user_action_time_idx
    )

    # Composite index for request log queries (user + time)
    create_if_not_exists index(:request_logs, [:user_id, :inserted_at],
      name: :request_logs_user_time_idx
    )

    # Index for IP-based request log queries (security/rate limiting)
    create_if_not_exists index(:request_logs, [:ip_address, :inserted_at],
      name: :request_logs_ip_time_idx
    )

    # Composite index for OTP cleanup (already exists but ensuring)
    # This was added in migration 20260310081500_add_otp_indexes.exs
  end
end
