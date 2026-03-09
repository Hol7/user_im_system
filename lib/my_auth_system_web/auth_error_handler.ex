defmodule MyAuthSystemWeb.AuthErrorHandler do
  @moduledoc false

  import Plug.Conn

  # Keep optional Guardian pipelines (GraphiQL, public GraphQL queries) from crashing
  # when no bearer token is provided.
  def auth_error(conn, {:no_resource_found, _reason}, _opts), do: conn

  def auth_error(conn, {type, _reason}, _opts) when type in [:unauthenticated, :invalid_token] do
    body = Jason.encode!(%{error: "Unauthorized"})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
    |> halt()
  end

  def auth_error(conn, _error, _opts), do: conn
end
