defmodule MyAuthSystem.Repo.Migrations.CreateOtps do
  use Ecto.Migration

  def change do
    create table(:otps, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :code_hash, :string, null: false
      add :purpose, :string, null: false, default: "login"
      add :expires_at, :utc_datetime, null: false
      add :used, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:otps, [:user_id, :purpose, :used])
    create index(:otps, [:expires_at])
  end
end
