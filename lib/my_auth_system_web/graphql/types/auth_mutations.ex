defmodule MyAuthSystemWeb.GraphQL.Types.AuthMutations do
  use Absinthe.Schema.Notation

  object :password_reset_mutations do
    field :request_password_reset, :password_reset_payload do
      arg(:email, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.request_password_reset/3)
    end

    field :reset_password, :password_reset_payload do
      arg(:otp_id, non_null(:id))
      arg(:code, non_null(:string))
      arg(:new_password, non_null(:string))
      arg(:new_password_confirmation, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.reset_password/3)
    end
  end

  object :password_reset_payload do
    field :message, :string
    field :otp_id, :id
  end
end
