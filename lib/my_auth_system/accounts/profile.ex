defmodule MyAuthSystem.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "profiles" do
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :country, :string
    field :city, :string
    field :district, :string
    field :avatar_path, :string

    belongs_to :user, MyAuthSystem.Accounts.User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:first_name, :last_name, :phone, :country, :city, :district, :avatar_path])
    |> validate_required([:first_name, :last_name, :phone, :country, :city])
    |> validate_format(:phone, ~r/^\+?[0-9\s\-()]{8,20}$/, message: "invalid phone format")
    |> unique_constraint(:user_id)
  end
end
