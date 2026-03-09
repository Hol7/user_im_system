defmodule MyAuthSystem.Monitoring.RequestLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "request_logs" do
    field :operation_name, :string
    field :query, :string
    field :variables, :map
    field :response_status, :integer
    field :response_data, :map
    field :errors, :map
    field :duration_ms, :integer
    field :ip_address, :string
    field :user_agent, :string
    field :request_id, :string

    belongs_to :user, MyAuthSystem.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(request_log, attrs) do
    request_log
    |> cast(attrs, [
      :user_id,
      :operation_name,
      :query,
      :variables,
      :response_status,
      :response_data,
      :errors,
      :duration_ms,
      :ip_address,
      :user_agent,
      :request_id
    ])
    |> validate_required([:query, :response_status])
  end
end
