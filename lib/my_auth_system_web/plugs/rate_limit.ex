# lib/my_auth_system_web/plugs/rate_limit.ex
defmodule MyAuthSystemWeb.Plugs.RateLimit do
  @moduledoc """
  Plug de rate limiting basé sur ETS (sans Redis).
  Limite les requêtes par IP pour les endpoints sensibles.
  """

  import Plug.Conn
  use GenServer

  # Configuration par défaut
  # requêtes
  @default_limit 5
  # millisecondes (1 minute)
  @default_window 60_000
  @ets_table :auth_rate_limit

  def init(opts) do
    Keyword.validate!(opts,
      limit: @default_limit,
      window_ms: @default_window,
      key_extractor: &get_ip/1
    )
  end

  def call(conn, opts) do
    limit = Keyword.fetch!(opts, :limit)
    window_ms = Keyword.fetch!(opts, :window_ms)
    key_extractor = Keyword.fetch!(opts, :key_extractor)

    key = key_extractor.(conn)

    case check_rate(key, limit, window_ms) do
      {:ok, _count} ->
        conn

      {:error, _count} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("retry-after", "#{div(window_ms, 1000)}")
        |> send_resp(429, Jason.encode!(%{error: "Too many requests. Try again later."}))
        |> halt()
    end
  end

  # === HELPER: Extraire l'IP du client ===
  def get_ip(conn) do
    conn
    |> Plug.Conn.get_req_header("x-forwarded-for")
    |> List.first()
    |> case do
      nil ->
        conn.remote_ip
        |> Tuple.to_list()
        |> Enum.join(".")

      ip ->
        String.split(ip, ",") |> List.first() |> String.trim()
    end
  end

  # Vérifier et incrémenter le compteur
  defp check_rate(key, limit, window_ms) do
    now = System.system_time(:millisecond)
    window_start = now - window_ms

    # Nettoyer les anciennes entrées (simple GC)
    cleanup_old_entries(window_start)

    # Récupérer l'historique des timestamps pour cette clé
    timestamps =
      case :ets.lookup(@ets_table, key) do
        [{^key, ts_list}] -> ts_list
        [] -> []
      end

    # Filtrer les timestamps dans la fenêtre actuelle
    valid_timestamps = Enum.filter(timestamps, &(&1 >= window_start))

    if length(valid_timestamps) >= limit do
      {:error, length(valid_timestamps) + 1}
    else
      # Ajouter le timestamp actuel et sauvegarder
      new_timestamps = [now | valid_timestamps]
      :ets.insert(@ets_table, {key, new_timestamps})
      {:ok, length(new_timestamps)}
    end
  end

  # Nettoyer les entrées expirées (appelé périodiquement)
  defp cleanup_old_entries(window_start) do
    :ets.select(@ets_table, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.each(fn {key, timestamps} ->
      valid = Enum.filter(timestamps, &(&1 >= window_start))

      if valid == [],
        do: :ets.delete(@ets_table, key),
        else: :ets.insert(@ets_table, {key, valid})
    end)
  end

  # Initialiser la table ETS au démarrage de l'app
  def setup do
    :ets.new(@ets_table, [
      :named_table,
      :public,
      :set,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    # Lancer un processus pour le cleanup périodique (optionnel)
    # Task.start_link(fn -> cleanup_loop() end)
  end
end
