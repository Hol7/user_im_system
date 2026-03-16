defmodule MyAuthSystem.Repo.Migrations.AddArchivedStatusToUsers do
  use Ecto.Migration

  def up do
    # Status is stored as string, not enum type
    # The :archived value is handled at application level via Ecto.Enum
    # No database migration needed - just documenting the change
    :ok
  end

  def down do
    :ok
  end
end
