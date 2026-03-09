defmodule MyAuthSystem.Audit.Log do
  @moduledoc """
  The Audit Log schema.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MyAuthSystem.Workers.AuditLogWorker

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

  @doc """
  Creates a changeset for audit log.
  """
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:user_id, :action, :metadata, :ip_address, :user_agent])
    |> validate_required([:action])
  end

  @doc """
  Creates an audit log entry asynchronously via Oban.
  """
  def log_async(user_id, action, metadata, conn) do
    AuditLogWorker.new(%{
      user_id: user_id,
      action: action,
      metadata: metadata,
      ip_address: get_ip(conn),
      user_agent: get_user_agent(conn)
    })
    |> Oban.insert()
  end

  defp get_ip(conn) when is_nil(conn), do: nil

  defp get_ip(conn) do
    conn
    |> Plug.Conn.get_req_header("x-forwarded-for")
    |> List.first()
    |> case do
      nil ->
        conn.remote_ip
        |> Tuple.to_list()
        |> Enum.join(".")

      ip ->
        String.split(ip, ",")
        |> List.first()
        |> String.trim()
    end
  end

  defp get_user_agent(conn) when is_nil(conn), do: nil

  defp get_user_agent(conn) do
    conn
    |> Plug.Conn.get_req_header("user-agent")
    |> List.first()
    |> case do
      nil -> "unknown"
      agent -> agent
    end
  end
end
