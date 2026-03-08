defmodule MyAuthSystem.Repo do
  use Ecto.Repo,
    otp_app: :my_auth_system,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Dynamically configure the database URL based on runtime
  environment variables.
  """
  def init(_type, config) do
    {:ok, Keyword.put(config, :url, System.get_env("DATABASE_URL"))}
  end
end
