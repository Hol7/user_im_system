defmodule MyAuthSystem.Repo.Migrations.CreateRequestLogs do
  use Ecto.Migration

  def change do
    create table(:request_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :operation_name, :string
      add :query, :text
      add :variables, :map
      add :response_status, :integer
      add :response_data, :map
      add :errors, :map
      add :duration_ms, :integer
      add :ip_address, :string
      add :user_agent, :text
      add :request_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:request_logs, [:user_id])
    create index(:request_logs, [:operation_name])
    create index(:request_logs, [:response_status])
    create index(:request_logs, [:inserted_at])
    create index(:request_logs, [:request_id])
  end
end
