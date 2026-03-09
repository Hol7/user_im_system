defmodule MyAuthSystemWeb.PageController do
  use MyAuthSystemWeb, :controller

  def home(conn, _params) do
    conn
    |> put_status(:found)
    |> redirect(to: "/api/graphiql")
  end

  def not_found(conn, _params) do
    accept = get_req_header(conn, "accept") |> List.first() || ""

    cond do
      String.contains?(accept, "application/json") ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Not Found",
          message: "The requested resource does not exist.",
          graphql_endpoint: "/api/graphql",
          graphiql_playground: "/api/graphiql"
        })

      true ->
        conn
        |> put_status(:found)
        |> redirect(to: "/api/graphiql")
    end
  end
end
