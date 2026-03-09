defmodule MyAuthSystem.Application do
  @moduledoc """
  The main supervisor for the MyAuthSystem application.
  Starts all children processes including Repo, Endpoint, Oban, Finch, etc.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # === INITIALISATION ETS POUR RATE LIMITING ===
    # Doit être fait AVANT de démarrer les superviseurs
    initialize_rate_limit_ets()

    # === INITIALISATION DOSSIER UPLOAD ===
    initialize_upload_directory()

    # === CONFIGURATION DES ENFANTS ===
    children = [
      # Telemetry pour les métriques Phoenix
      MyAuthSystemWeb.Telemetry,

      # Base de données
      MyAuthSystem.Repo,

      # DNS Cluster pour le clustering Phoenix natif (1.8+)
      {DNSCluster, query: Application.get_env(:my_auth_system, :dns_cluster_query) || :ignore},

      # PubSub pour la communication entre processus/nœuds
      {Phoenix.PubSub, name: MyAuthSystem.PubSub},

      # Client HTTP pour les appels API (Brevo)
      {Finch, name: MyAuthSystem.Finch},

      # Queue de jobs asynchrones (emails, logs, cleanup)
      {Oban, Application.fetch_env!(:my_auth_system, Oban)},

      # Point d'entrée HTTP/HTTPS de l'application
      MyAuthSystemWeb.Endpoint
    ]

    # === STRATÉGIE DE SUPERVISION ===
    # one_for_one: si un enfant crash, il est redémarré seul
    opts = [strategy: :one_for_one, name: MyAuthSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    # Recharger la configuration de l'endpoint à chaud (hot reload en dev)
    MyAuthSystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # === FONCTIONS PRIVÉES D'INITIALISATION ===

  # defp initialize_rate_limit_ets do
  #   :ets.new(:auth_rate_limit, [
  #     :named_table,
  #     :public,
  #     :set,
  #     {:read_concurrency, true},
  #     {:write_concurrency, true}
  #   ])

  #   # Optionnel: lancer un processus de cleanup périodique
  #   # Task.start_link(&MyAuthSystemWeb.Plugs.RateLimit.cleanup_loop/0)
  # end

  defp initialize_rate_limit_ets do
    MyAuthSystemWeb.Plugs.RateLimit.setup()
  end

  defp initialize_upload_directory do
    upload_path =
      Application.get_env(:my_auth_system, :upload_path) ||
        Path.join([:code.priv_dir(:my_auth_system), "static", "uploads"])

    case File.mkdir_p(upload_path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to create upload directory #{upload_path}: #{inspect(reason)}")
        # Ne pas faire crasher l'app pour ça
        :ok
    end
  end
end

# defmodule MyAuthSystem.Application do
#   # See https://hexdocs.pm/elixir/Application.html
#   # for more information on OTP Applications
#   @moduledoc false

#   use Application

#   @impl true
#   def start(_type, _args) do
#     children = [
#       MyAuthSystemWeb.Telemetry,
#       MyAuthSystem.Repo,
#       {DNSCluster, query: Application.get_env(:my_auth_system, :dns_cluster_query) || :ignore},
#       {Phoenix.PubSub, name: MyAuthSystem.PubSub},
#       {Finch, name: MyAuthSystem.Finch},
#       {Oban, Application.fetch_env!(:my_auth_system, Oban)},
#       # Start a worker by calling: MyAuthSystem.Worker.start_link(arg)
#       # {MyAuthSystem.Worker, arg},
#       # Start to serve requests, typically the last entry
#       MyAuthSystemWeb.Endpoint
#     ]

#     # See https://hexdocs.pm/elixir/Supervisor.html
#     # for other strategies and supported options
#     opts = [strategy: :one_for_one, name: MyAuthSystem.Supervisor]
#     Supervisor.start_link(children, opts)
#   end

#   # Tell Phoenix to update the endpoint configuration
#   # whenever the application is updated.
#   @impl true
#   def config_change(changed, _new, removed) do
#     MyAuthSystemWeb.Endpoint.config_change(changed, removed)
#     :ok
#   end
# end
