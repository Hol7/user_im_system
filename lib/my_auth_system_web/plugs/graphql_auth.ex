defmodule MyAuthSystemWeb.Plugs.GraphQLAuth do
  @moduledoc """
  Plug to set current_user in GraphQL context based on JWT token.
  This replaces the schema-level middleware approach.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = current_user_from_authorization(conn)

    Absinthe.Plug.put_options(conn,
      context: %{
        current_user: current_user,
        pubsub: MyAuthSystem.PubSub
      }
    )
  end

  defp current_user_from_authorization(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- MyAuthSystem.Auth.GuardianToken.decode_and_verify(token),
         {:ok, user} <- MyAuthSystem.Auth.GuardianToken.resource_from_claims(claims) do
      user
    else
      _ -> nil
    end
  end
end
