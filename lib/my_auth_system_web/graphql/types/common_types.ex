defmodule MyAuthSystemWeb.GraphQL.Types.CommonTypes do
  use Absinthe.Schema.Notation

  # Common enums used across the schema
  enum :user_role do
    value(:USER, as: :user)
    value(:ADMIN, as: :admin)
    value(:SUPER_ADMIN, as: :super_admin)
  end

  enum :user_status do
    value(:ACTIVE, as: :active)
    value(:PENDING_VERIFICATION, as: :pending_verification)
    value(:SUSPENDED, as: :suspended)
    value(:DELETION_REQUESTED, as: :deletion_requested)
  end
end
