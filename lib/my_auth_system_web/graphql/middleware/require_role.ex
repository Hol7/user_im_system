defmodule MyAuthSystemWeb.GraphQL.Middleware.RequireRole do
  @moduledoc """
  Middleware to ensure user has required role(s).
  Usage: middleware RequireRole, [:admin, :super_admin]
  """
  def call(%{context: %{current_user: user}} = resolution, roles) when is_list(roles) do
    if user.role in roles do
      resolution
    else
      Absinthe.Resolution.put_result(resolution, {:error, "Insufficient permissions"})
    end
  end

  def call(resolution, _roles) do
    Absinthe.Resolution.put_result(resolution, {:error, "Authentication required"})
  end
end
