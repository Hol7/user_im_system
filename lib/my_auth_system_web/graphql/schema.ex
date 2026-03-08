defmodule MyAuthSystemWeb.GraphQL.Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  # Import all types
  import_types(MyAuthSystemWeb.GraphQL.Types.PublicAuthMutations)
  import_types(MyAuthSystemWeb.GraphQL.Types.UserMutations)
  import_types(MyAuthSystemWeb.GraphQL.Types.AdminMutations)
  import_types(MyAuthSystemWeb.GraphQL.Types.UserQueries)
  import_types(MyAuthSystemWeb.GraphQL.Types.AdminQueries)
  import_types(MyAuthSystemWeb.GraphQL.Types.AuthMutations)

  import_types(MyAuthSystemWeb.GraphQL.Types.User)
  import_types(MyAuthSystemWeb.GraphQL.Types.Profile)
  import_types(MyAuthSystemWeb.GraphQL.Types.AuthPayload)
  import_types(MyAuthSystemWeb.GraphQL.Types.AdminPayload)

  # Middleware for auth (applied globally)
  middleware(fn resolve, _ ->
    case Guardian.Plug.current_resource(resolve.context) do
      %MyAuthSystem.Accounts.User{status: :active} = user ->
        Absinthe.Resolution.put_result(
          resolve,
          {:ok, Map.put(resolve.context, :current_user, user)}
        )

      _ ->
        # Allow public mutations to proceed without auth
        if resolve.definition.name in [
             :register,
             :login,
             :verify_otp,
             :request_password_reset,
             :reset_password
           ] do
          resolve
        else
          Absinthe.Resolution.put_result(resolve, {:error, "Unauthorized"})
        end
    end
  end)

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

    # Password Reset
    import_fields(:password_reset_mutations)
  end
end
