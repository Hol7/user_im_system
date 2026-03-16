defmodule MyAuthSystem.Auth.PasswordResetToken do
  @moduledoc """
  Schema for secure password reset tokens.
  Follows OWASP Forgot Password Cheat Sheet recommendations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "password_reset_tokens" do
    field :token_hash, :string
    field :expires_at, :utc_datetime
    field :used, :boolean, default: false
    field :used_at, :utc_datetime

    belongs_to :user, MyAuthSystem.Accounts.User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token_hash, :expires_at, :used, :used_at, :user_id])
    |> validate_required([:token_hash, :expires_at, :user_id])
  end

  @doc """
  Generate a cryptographically secure random token.
  Returns {plain_token, hashed_token} tuple.
  """
  def generate_secure_token do
    # Generate 32 bytes (256 bits) of cryptographically secure random data
    plain_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hashed_token = Argon2.hash_pwd_salt(plain_token)
    {plain_token, hashed_token}
  end

  @doc """
  Create a password reset token for a user.
  Token expires in 1 hour as per OWASP recommendations.
  """
  def create_for_user(user_id) do
    {plain_token, hashed_token} = generate_secure_token()
    expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) # 1 hour

    token = %__MODULE__{
      user_id: user_id,
      token_hash: hashed_token,
      expires_at: expires_at
    }

    {plain_token, token}
  end

  @doc """
  Verify a password reset token.
  """
  def verify_token(token, plain_token_string) do
    cond do
      token.used -> {:error, :already_used}
      DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt -> {:error, :expired}
      Argon2.verify_pass(plain_token_string, token.token_hash) -> {:ok, :valid}
      true -> {:error, :invalid}
    end
  end
end
