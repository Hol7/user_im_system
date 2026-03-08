defmodule MyAuthSystem.Auth.RefreshToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "refresh_tokens" do
    field :token_hash, :string
    field :expires_at, :utc_datetime
    field :revoked, :boolean, default: false
    field :user_agent, :string
    field :ip_address, :string

    belongs_to :user, MyAuthSystem.Accounts.User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(refresh_token, attrs) do
    refresh_token
    |> cast(attrs, [:token_hash, :expires_at, :revoked, :user_agent, :ip_address, :user_id])
    |> validate_required([:token_hash, :expires_at, :user_id])
  end
end
