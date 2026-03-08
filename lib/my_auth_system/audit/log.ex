defmodule MyAuthSystem.Audit.Log do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_logs" do
    field :user_id, :binary_id
    field :action, :string
    field :metadata, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:user_id, :action, :metadata, :ip_address, :user_agent])
    |> validate_required([:action])
  end

  @doc """
  Crée un log d'audit de manière asynchrone via Oban.
  """
  def log_async(user_id, action, metadata, conn) do
    MyAuthSystem.Workers.AuditLogWorker
    |> new(%{
      user_id: user_id,
      action: action,
      meta metadata,
      ip_address: get_ip(conn),
      user_agent: get_user_agent(conn)
    })
    |> Oban.insert()
  end

  defp get_ip(conn), do: conn |> Plug.Conn.get_req_header("x-forwarded-for") |> List.first() || conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
  defp get_user_agent(conn), do: conn |> Plug.Conn.get_req_header("user-agent") |> List.first() || "unknown"
end
