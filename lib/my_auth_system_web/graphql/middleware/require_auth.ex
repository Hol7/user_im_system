defmodule MyAuthSystemWeb.GraphQL.Middleware.RequireAuth do
  @moduledoc """
  Middleware to ensure user is authenticated for protected fields.
  """
  def call(%{context: %{current_user: %MyAuthSystem.Accounts.User{}}} = resolution, _opts) do
    resolution
  end

  def call(resolution, _opts) do
    Absinthe.Resolution.put_result(resolution, {:error, "Authentication required"})
  end
end
