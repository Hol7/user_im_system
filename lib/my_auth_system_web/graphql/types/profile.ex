defmodule MyAuthSystemWeb.GraphQL.Types.Profile do
  use Absinthe.Schema.Notation

  object :profile do
    field :id, non_null(:id)
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :country, :string
    field :city, :string
    field :district, :string
    field :avatar_url, :string
    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
