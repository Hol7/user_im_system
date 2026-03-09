defmodule MyAuthSystemWeb.GraphQL.Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  # Import all types
  import_types(MyAuthSystemWeb.GraphQL.Types.CommonTypes)
  import_types(MyAuthSystemWeb.GraphQL.Types.User)
  import_types(MyAuthSystemWeb.GraphQL.Types.Profile)
  import_types(MyAuthSystemWeb.GraphQL.Types.PublicAuthMutations)
  import_types(MyAuthSystemWeb.GraphQL.Types.UserMutations)
  import_types(MyAuthSystemWeb.GraphQL.Types.AdminMutations)
  import_types(MyAuthSystemWeb.GraphQL.Types.UserQueries)
  import_types(MyAuthSystemWeb.GraphQL.Types.AdminQueries)

  # === QUERIES ===
  query do
    # Public health check
    field :health, :string do
      resolve(fn _, _, _ -> {:ok, "OK"} end)
    end

    # Import user queries (protected)
    import_fields(:user_queries)

    # Import admin queries (protected by middleware in router)
    import_fields(:admin_queries)
  end

  # === MUTATIONS ===
  mutation do
    # Public auth mutations (no auth required)
    import_fields(:public_auth_mutations)

    # Protected user mutations (auth required via router context)
    import_fields(:user_mutations)

    # Admin mutations (role check via router context)
    import_fields(:admin_mutations)
  end
end
