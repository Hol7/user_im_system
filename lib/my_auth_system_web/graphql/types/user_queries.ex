defmodule MyAuthSystemWeb.GraphQL.Types.UserQueries do
  use Absinthe.Schema.Notation

  object :user_queries do
    field :me, :user do
      resolve(&MyAuthSystemWeb.GraphQL.Resolvers.UserResolver.get_me/3)
    end
  end
end
