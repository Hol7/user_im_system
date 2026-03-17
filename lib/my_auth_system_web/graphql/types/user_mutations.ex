defmodule MyAuthSystemWeb.GraphQL.Types.UserMutations do
  use Absinthe.Schema.Notation

  object :user_mutations do
    field :logout, :message_payload do
      arg(:refresh_token, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.UserResolver.logout/3)
    end

    field :update_profile, :profile_payload do
      arg(:input, non_null(:profile_input))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.UserResolver.update_profile/3)
    end

    field :request_account_deletion, :message_payload do
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.UserResolver.request_deletion/3)
    end
  end

  # Input types
  input_object :profile_input do
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :country, :string
    field :city, :string
    field :district, :string
    field :avatar_url, :string
  end

  # Payload types
  object :profile_payload do
    field :profile, :profile
    field :message, :string
  end
end
