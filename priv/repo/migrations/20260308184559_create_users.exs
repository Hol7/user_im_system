defmodule MyAuthSystem.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false, default: "user"
      add :status, :string, null: false, default: "pending_verification"
      add :last_login_at, :utc_datetime
      add :email_verified_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email], where: "deleted_at IS NULL")
    create index(:users, [:status])
    create index(:users, [:role])
  end
end
