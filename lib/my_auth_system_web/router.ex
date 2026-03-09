defmodule MyAuthSystemWeb.Router do
  use MyAuthSystemWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session

    plug MyAuthSystemWeb.Plugs.RateLimit,
      limit: 5,
      window_ms: 60_000,
      key_extractor: &MyAuthSystemWeb.Plugs.RateLimit.get_ip/1

    plug Guardian.Plug.VerifyHeader, realm: "Bearer", optional: true
    plug Guardian.Plug.LoadResource, optional: true
    plug MyAuthSystemWeb.Plugs.GraphQLAuth
  end

  pipeline :graphql_playground do
    plug :accepts, ["json"]
    plug Guardian.Plug.VerifyHeader, realm: "Bearer", optional: true
    plug Guardian.Plug.LoadResource, optional: true
    plug MyAuthSystemWeb.Plugs.GraphQLAuth
  end

  # === GRAPHQL ENDPOINT ===
  scope "/api", MyAuthSystemWeb do
    pipe_through :api

    forward "/graphql", Absinthe.Plug,
      schema: MyAuthSystemWeb.GraphQL.Schema,
      context: %{pubsub: MyAuthSystem.PubSub}
  end

  # === GRAPHIQL PLAYGROUND (Dev Only) ===
  if Mix.env() in [:dev, :test] do
    scope "/" do
      pipe_through [:browser]
      forward "/oban", ObanWeb.Plug
    end

    scope "/api", MyAuthSystemWeb do
      pipe_through :graphql_playground

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: MyAuthSystemWeb.GraphQL.Schema,
        interface: :playground,
        default_url: "/api/graphql"
    end
  end

  # === API ENDPOINTS ===
  scope "/api", MyAuthSystemWeb do
    pipe_through :api

    # GraphQL principal (avec auth)
    forward "/graphql", Absinthe.Plug,
      schema: MyAuthSystemWeb.GraphQL.Schema,
      context: %{pubsub: MyAuthSystem.PubSub}

    # Upload endpoint
    post "/upload/avatar", UploadController, :upload_avatar
  end

  # === GRAPHIQL PLAYGROUND (Dev uniquement) [[web_extractor]]
  if Mix.env() in [:dev, :test] do
    scope "/api", MyAuthSystemWeb do
      pipe_through :graphql_playground

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: MyAuthSystemWeb.GraphQL.Schema,
        # Options: :advanced, :simple, :playground
        interface: :playground,
        default_url: "/api/graphql",
        socket_url: "/socket",
        default_headers: {__MODULE__, :graphiql_headers}
    end
  end

  # === UPLOAD ENDPOINT ===
  scope "/api", MyAuthSystemWeb do
    pipe_through :api
    post "/upload/avatar", UploadController, :upload_avatar
  end


  # === PUBLIC AUTH ROUTES (REST fallback) ===
  # Commented out - using GraphQL API instead
  # scope "/api", MyAuthSystemWeb do
  #   post "/auth/register", AuthController, :register
  #   post "/auth/login", AuthController, :login_request
  #   post "/auth/verify-otp", AuthController, :verify_otp
  #   post "/auth/refresh", AuthController, :refresh_token
  #   get "/auth/validate-email", AuthController, :validate_email
  # end

  #  # === PUBLIC AUTH ROUTES ===
  # scope "/api", MyAuthSystemWeb do
  #   post "/auth/register", AuthController, :register
  #   post "/auth/login", AuthController, :login_request
  #   post "/auth/verify-otp", AuthController, :verify_otp
  #   post "/auth/refresh", AuthController, :refresh_token
  #   # Validation email (GET pour le lien dans l'email)
  #   get "/auth/validate-email", AuthController, :validate_email
  # end

  # # === OBAN DASHBOARD ===
  # if Mix.env() in [:dev, :test] do
  #   scope "/" do
  #     pipe_through [:browser]
  #     import Oban.Web.Router

  #     oban_dashboard("/oban",
  #       basic_auth: [
  #         username: "admin",
  #         password: System.get_env("OBAN_DASHBOARD_PASS", "change_me")
  #       ]
  #     )
  #   end
  # end

  # === OBAN DASHBOARD ===
  if Mix.env() in [:dev, :test] do
    scope "/" do
      pipe_through [:browser]
      import Oban.Web.Router

      oban_dashboard("/oban",
        basic_auth: [
          username: "admin",
          password: System.get_env("OBAN_DASHBOARD_PASS", "change_me")
        ]
      )
    end
  end

  # pipeline :admin do
  #   plug MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin]
  # end

  # scope "/api", MyAuthSystemWeb do
  #   pipe_through :api

  #   # GraphQL endpoint
  #   forward "/graphql", Absinthe.Plug,
  #     schema: MyAuthSystemWeb.GraphQL.Schema,
  #     context: %{pubsub: MyAuthSystem.PubSub}

  #   # Upload endpoint (REST car GraphQL n'est pas idéal pour les fichiers)
  #   post "/upload/avatar", UploadController, :upload_avatar
  # end

  # scope "/api", MyAuthSystemWeb do
  #   # Routes publiques (pas d'auth requise)
  #   post "/auth/register", AuthController, :register
  #   post "/auth/login", AuthController, :login_request
  #   post "/auth/verify-otp", AuthController, :verify_otp
  #   post "/auth/refresh", AuthController, :refresh_token
  # end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:my_auth_system, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
