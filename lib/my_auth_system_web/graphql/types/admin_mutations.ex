defmodule MyAuthSystemWeb.GraphQL.Types.AdminMutations do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  object :admin_mutations do
    field :admin_create_user, :admin_user_payload do
      arg(:input, non_null(:admin_user_input))
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.create_user/3)
    end

    field :admin_update_user, :admin_user_payload do
      arg(:id, non_null(:id))
      arg(:input, non_null(:admin_user_input))
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.update_user/3)
    end

    field :admin_delete_user, :message_payload do
      arg(:id, non_null(:id))
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.delete_user/3)
    end

    field :admin_validate_user, :admin_user_payload do
      arg(:id, non_null(:id))
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.validate_user/3)
    end

    field :admin_process_deletion_request, :message_payload do
      arg(:id, non_null(:id))
      # :approve or :reject
      arg(:action, non_null(:deletion_action))
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.process_deletion/3)
    end
  end

  input_object :admin_user_input do
    field :email, :string
    # Optional: only for creation
    field :password, :string
    field :password_confirmation, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :country, :string
    field :city, :string
    field :district, :string
    field :role, :user_role
    field :status, :user_status
    field :avatar_path, :string
  end

  enum :user_role do
    value(:user)
    value(:admin)
    value(:super_admin)
  end

  enum :user_status do
    value(:active)
    value(:pending_verification)
    value(:suspended)
    value(:deletion_requested)
  end

  enum :deletion_action do
    value(:approve)
    value(:reject)
  end

  object :admin_user_payload do
    field :user, :user
    field :message, :string
  end
end
