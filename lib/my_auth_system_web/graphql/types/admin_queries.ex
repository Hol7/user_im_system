defmodule MyAuthSystemWeb.GraphQL.Types.AdminQueries do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  object :admin_queries do
    # List users with filtering/pagination
    connection node_type: :user do
      field :admin_users, node_type: :user do
        arg(:status, :user_status)
        arg(:role, :user_role)
        arg(:search, :string)
        arg(:sort_by, :user_sort_field, default_value: :inserted_at)
        arg(:sort_order, :sort_order, default_value: :desc)
        middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
        resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.list_users/3)
      end
    end

    # Get single user by ID
    field :admin_user, :user do
      arg(:id, non_null(:id))
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.get_user/3)
    end

    # List pending deletion requests
    field :admin_deletion_requests, list_of(:user) do
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.list_deletion_requests/3)
    end

    # Audit logs for a user
    field :admin_audit_logs, list_of(:audit_log) do
      arg(:user_id, :id)
      arg(:action, :string)
      arg(:limit, :integer, default_value: 50)
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver.list_audit_logs/3)
    end
  end

  enum :user_sort_field do
    value(:inserted_at)
    value(:last_login_at)
    value(:email)
  end

  enum :sort_order do
    value(:asc)
    value(:desc)
  end

  object :audit_log do
    field :id, non_null(:id)
    field :user_id, :id
    field :action, non_null(:string)
    field :metadata, :map
    field :ip_address, :string
    field :inserted_at, non_null(:datetime)
  end
end
