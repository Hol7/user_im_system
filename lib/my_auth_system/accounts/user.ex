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
      values: [:active, :pending_verification, :suspended, :deletion_requested, :archived],
      default: :pending_verification

    field :last_login_at, :utc_datetime
    field :email_verified_at, :utc_datetime
    field :deleted_at, :utc_datetime
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

  # Inside lib/my_auth_system/accounts/user.ex

  @doc """
  Changeset for Admin updates.
  Allows admins to modify sensitive fields like role and status that normal users cannot.
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :role, :status, :password, :password_confirmation])
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, [:user, :admin, :super_admin])
    |> validate_inclusion(:status, [
      :active,
      :pending_verification,
      :suspended,
      :deletion_requested,
      :deleted
    ])
    |> maybe_hash_password()
  end

  defp maybe_hash_password(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
  end

  defp maybe_hash_password(changeset), do: changeset

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
