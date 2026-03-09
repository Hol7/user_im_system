defmodule MyAuthSystem.Repo.Migrations.CreateRefreshTokensTable do
  use Ecto.Migration

  def change do
    create table(:refresh_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked, :boolean, default: false, null: false
      add :user_agent, :string
      add :ip_address, :string

      timestamps(type: :utc_datetime)
    end

    create index(:refresh_tokens, [:user_id, :revoked])
    create index(:refresh_tokens, [:expires_at])
    create index(:refresh_tokens, [:token_hash], unique: true)
  end
end
