# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

import Config

# General application configuration
config :my_auth_system,
  ecto_repos: [MyAuthSystem.Repo],
  generators: [timestamp_type: :utc_datetime]

# Endpoint configuration
config :my_auth_system, MyAuthSystemWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: MyAuthSystemWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MyAuthSystem.PubSub,
  live_view: [signing_salt: "v4JaJZ4x"]

# Logger configuration - CORRECT SYNTAX
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :action]

# Default logger formatter
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :my_auth_system, Oban,
  repo: MyAuthSystem.Repo,
  plugins: [
    {Oban.Plugins.Pruner,
     max_age: 60 * 60 * 24 * 7,
     limit: 10_000,
     interval: :timer.minutes(30),
     max_age_by_state: %{
       completed: 60 * 60 * 24 * 7,
       discarded: 60 * 60 * 24 * 30,
       cancelled: 60 * 60 * 24 * 30
     }},
    Oban.Plugins.Lifeline,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", MyAuthSystem.Workers.CleanupOtpWorker, args: %{older_than_hours: 1}},
       {"0 2 * * *", MyAuthSystem.Workers.CleanupAuditLogsWorker, args: %{older_than_days: 90}},
       {"0 3 * * *", MyAuthSystem.Workers.CleanupRequestLogsWorker, args: %{older_than_days: 90}}
     ]}
  ],
  queues: [
    default: 20,
    emails: 30,
    audits: 10,
    uploads: 10
  ]

if config_env() != :prod do
  config :my_auth_system, ObanWeb,
    repo: MyAuthSystem.Repo,
    plug: [at: "/oban", basic_auth: [username: "admin", password: "secure_password"]]
end

# Phoenix JSON library
config :phoenix, :json_library, Jason

# Mailer (local adapter for dev)
config :my_auth_system, MyAuthSystem.Mailer, adapter: Swoosh.Adapters.Local

# Asset tools
config :esbuild,
  version: "0.25.4",
  my_auth_system: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.12",
  my_auth_system: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/css/app.css),
    cd: Path.expand("..", __DIR__)
  ]

# Import environment-specific config (MUST stay at bottom)
import_config "#{config_env()}.exs"

# This file is responsible for configuring your application
# # and its dependencies with the aid of the Config module.
# #
# # This configuration file is loaded before any dependency and
# # is restricted to this project.

# # General application configuration
# import Config

# config :my_auth_system,
#   ecto_repos: [MyAuthSystem.Repo],
#   generators: [timestamp_type: :utc_datetime]

# # Configure the endpoint
# config :my_auth_system, MyAuthSystemWeb.Endpoint,
#   url: [host: "localhost"],
#   adapter: Bandit.PhoenixAdapter,
#   render_errors: [
#     formats: [json: MyAuthSystemWeb.ErrorJSON],
#     layout: false
#   ],
#   pubsub_server: MyAuthSystem.PubSub,
#   live_view: [signing_salt: "v4JaJZ4x"]

#  #new config start

# config :my_auth_system, MyAuthSystem.Repo,
#   username: System.get_env("DB_USERNAME", "postgres"),
#   password: System.get_env("DB_PASSWORD", "postgres"),
#   database: System.get_env("DB_NAME", "my_auth_system_dev"),
#   hostname: System.get_env("DB_HOST", "localhost"),
#   pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "50")) # Augmenté pour le scale

# config :my_auth_system, MyAuthSystemWeb.Endpoint,
#   url: [host: "localhost"],
#   adapter: Bandit.PhoenixAdapter,
#   render_errors: [formats: [json: MyAuthSystemWeb.ErrorJSON], layout: false],
#   pubsub_server: MyAuthSystem.PubSub,
#   live_view: [signing_salt: "your_signing_salt_here"]

# config :my_auth_system, Oban,
#   repo: MyAuthSystem.Repo,
#   plugins: [Oban.Plugins.Pruner],
#   queues: [default: 10, emails: 20, audits: 5]

# config :my_auth_system, Guardian,
#   issuer: "my_auth_system",
#   secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY"),
#   token_verify_module: Guardian.Token.Jwt,
#   ttl: {15, :minutes},
#   allowed_algos: ["HS512"],
#   verify_module: Guardian.JWT,
#   permission: %{default: [:read, :write]},
#   token_module: MyAuthSystem.Auth.GuardianToken

# config :logger, :console,
#   format: "$time $metadata[$level] $message\n",
#   metadata [:request_id, :user_id, :action]

# #new config end

# # Configure the mailer
# #
# # By default it uses the "Local" adapter which stores the emails
# # locally. You can see the emails in your browser, at "/dev/mailbox".
# #
# # For production it's recommended to configure a different adapter
# # at the `config/runtime.exs`.
# config :my_auth_system, MyAuthSystem.Mailer, adapter: Swoosh.Adapters.Local

# # Configure esbuild (the version is required)
# config :esbuild,
#   version: "0.25.4",
#   my_auth_system: [
#     args:
#       ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
#     cd: Path.expand("../assets", __DIR__),
#     env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
#   ]

# # Configure tailwind (the version is required)
# config :tailwind,
#   version: "4.1.12",
#   my_auth_system: [
#     args: ~w(
#       --input=assets/css/app.css
#       --output=priv/static/assets/css/app.css
#     ),
#     cd: Path.expand("..", __DIR__)
#   ]

# # Configure Elixir's Logger
# config :logger, :default_formatter,
#   format: "$time $metadata[$level] $message\n",
#   metadata: [:request_id]

# # Use Jason for JSON parsing in Phoenix
# config :phoenix, :json_library, Jason

# # Import environment specific config. This must remain at the bottom
# # of this file so it overrides the configuration defined above.
# import_config "#{config_env()}.exs"
