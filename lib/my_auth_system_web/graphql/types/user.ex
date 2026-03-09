defmodule MyAuthSystemWeb.GraphQL.Types.User do
  use Absinthe.Schema.Notation

  object :user do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :role, non_null(:user_role)
    field :status, non_null(:user_status)
    field :last_login_at, :naive_datetime
    field :email_verified_at, :naive_datetime
    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
    field :profile, :profile
  end
end
