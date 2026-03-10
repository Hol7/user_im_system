defmodule MyAuthSystemWeb.GraphQL.Types.PublicAuthMutations do
  use Absinthe.Schema.Notation

  object :public_auth_mutations do
    field :register, :auth_payload do
      arg(:input, non_null(:register_input))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.register/3)
    end

    field :login, :otp_payload do
      arg(:email, non_null(:string))
      arg(:password, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.login/3)
    end

    field :verify_otp, :auth_payload do
      arg(:code, non_null(:string))
      arg(:email, :string)
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.verify_otp/3)
    end

    field :refresh_token, :auth_payload do
      arg(:refresh_token, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.refresh_token/3)
    end

    field :request_password_reset, :message_payload do
      arg(:email, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.request_password_reset/3)
    end

    field :reset_password, :message_payload do
      arg(:otp_id, non_null(:id))
      arg(:code, non_null(:string))
      arg(:new_password, non_null(:string))
      arg(:new_password_confirmation, non_null(:string))
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver.reset_password/3)
    end
  end

  # Input types
  input_object :register_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
    field :password_confirmation, non_null(:string)
    field :first_name, non_null(:string)
    field :last_name, non_null(:string)
    field :phone, non_null(:string)
    field :country, non_null(:string)
    field :city, non_null(:string)
    field :district, :string
  end

  # Payload types
  object :auth_payload do
    field :user, :user
    field :token, :string
    field :refresh_token, :string
    field :message, :string
  end

  object :otp_payload do
    field :message, non_null(:string)
    field :otp_id, :id
  end

  object :message_payload do
    field :message, non_null(:string)
  end
end
