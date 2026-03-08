defmodule MyAuthSystem.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :phone, :string, null: false
      add :country, :string, null: false
      add :city, :string, null: false
      add :district, :string
      add :avatar_path, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profiles, [:user_id])
    create index(:profiles, [:phone])
  end
end
