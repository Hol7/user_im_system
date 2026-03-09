defmodule MyAuthSystemWeb.GraphQL.Types.CommonTypes do
  use Absinthe.Schema.Notation

  # Common enums used across the schema
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
end
