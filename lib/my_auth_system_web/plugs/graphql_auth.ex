defmodule MyAuthSystemWeb.Plugs.GraphQLAuth do
  @moduledoc """
  Plug to set current_user in GraphQL context based on JWT token.
  This replaces the schema-level middleware approach.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = Guardian.Plug.current_resource(conn)

    # Add user to GraphQL context via conn assigns
    conn
    |> assign(:graphql_context, %{
      current_user: current_user,
      pubsub: MyAuthSystem.PubSub
    })
  end
end
