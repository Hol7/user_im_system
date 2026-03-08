defmodule MyAuthSystem.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :role, Ecto.Enum, values: [:user, :admin, :super_admin], default: :user

    field :status, Ecto.Enum,
      values: [:active, :pending_verification, :suspended, :deletion_requested],
      default: :pending_verification

    field :last_login_at, :utc_datetime
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    has_one :profile, MyAuthSystem.Accounts.Profile, on_replace: :update
    has_many :otps, MyAuthSystem.Auth.Otp, on_delete: :delete_all
    has_many :audit_logs, MyAuthSystem.Audit.Log, on_delete: :nilify_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation])
    |> validate_required([:email, :password, :password_confirmation])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:password, min: 8, max: 72)
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
