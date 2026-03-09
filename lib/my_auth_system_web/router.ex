defmodule MyAuthSystemWeb.Router do
  use MyAuthSystemWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "json"]
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

    plug MyAuthSystemWeb.Plugs.GraphQLAuth
  end

  pipeline :graphql_playground do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug MyAuthSystemWeb.Plugs.GraphQLAuth
  end

  # === API ENDPOINTS ===
  scope "/api" do
    pipe_through :api

    # GraphQL principal
    forward "/graphql", Absinthe.Plug,
      schema: MyAuthSystemWeb.GraphQL.Schema,
      context: %{pubsub: MyAuthSystem.PubSub}

    # Upload endpoint
    post "/upload/avatar", MyAuthSystemWeb.UploadController, :upload_avatar
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

  if Mix.env() in [:dev, :test] do
    # === GRAPHIQL PLAYGROUND ===
    scope "/api" do
      pipe_through :graphql_playground

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: MyAuthSystemWeb.GraphQL.Schema,
        interface: :playground,
        default_url: "/api/graphql"
    end

    # === OBAN DASHBOARD ===
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

    # === LIVE DASHBOARD ===
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:browser]

      live_dashboard "/dashboard",
        metrics: MyAuthSystemWeb.Telemetry,
        ecto_repos: [MyAuthSystem.Repo]
    end
  end

  # pipeline :admin do
  #   plug MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin]
  # end

  # Fallback for all unmatched routes
  scope "/", MyAuthSystemWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Catch-all for any unmatched routes (handles both JSON and HTML via content negotiation)
    match :*, "/*path", PageController, :not_found
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:my_auth_system, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
