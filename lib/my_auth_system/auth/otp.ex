defmodule MyAuthSystem.Auth.Otp do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "otps" do
    field :code_hash, :string

    field :purpose, Ecto.Enum,
      values: [:login, :password_reset, :email_verification],
      default: :login

    field :expires_at, :utc_datetime
    field :used, :boolean, default: false

    belongs_to :user, MyAuthSystem.Accounts.User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Generate OTP struct with pre-computed plain text code.
  Use this when you need to send the code via email before storing.
  """
  def generate_otp_with_code(user_id, purpose, plain_code) do
    expires_at = DateTime.add(DateTime.utc_now(), 5, :minute)

    %__MODULE__{
      user_id: user_id,
      code_hash: Argon2.hash_pwd_salt(plain_code),
      purpose: purpose,
      expires_at: expires_at
    }
  end

  @doc """
  Generate OTP with random code (legacy, for internal use).
  """
  def generate_otp(user_id, purpose) do
    code = generate_random_code()
    generate_otp_with_code(user_id, purpose, code)
  end

  defp generate_random_code do
    :crypto.strong_rand_bytes(3)
    |> :binary.bin_to_list()
    |> Enum.map(&rem(&1, 10))
    |> Enum.join()
  end

  def verify_otp(otp, code) do
    cond do
      otp.used -> {:error, :already_used}
      DateTime.compare(otp.expires_at, DateTime.utc_now()) == :lt -> {:error, :expired}
      Argon2.verify_pass(code, otp.code_hash) -> {:ok, :valid}
      true -> {:error, :invalid}
    end
  end

  def changeset(otp, attrs) do
    otp
    |> cast(attrs, [:code_hash, :purpose, :expires_at, :used, :user_id])
    |> validate_required([:code_hash, :purpose, :expires_at, :user_id])
  end
end
