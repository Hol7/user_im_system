defmodule MyAuthSystemWeb.GraphQL.Types.MonitoringQueries do
  use Absinthe.Schema.Notation
  import Ecto.Query
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Monitoring.RequestLog

  object :monitoring_queries do
    @desc "Get recent request logs (admin only)"
    field :request_logs, list_of(:request_log) do
      arg(:limit, :integer, default_value: 50)
      arg(:user_id, :id)
      arg(:operation_name, :string)
      arg(:status, :integer)
      middleware(MyAuthSystemWeb.GraphQL.Middleware.RequireRole, [:admin, :super_admin])
      resolve(&resolve_request_logs/3)
    end
  end

  object :request_log do
    field :id, non_null(:id)
    field :user_id, :id
    field :operation_name, :string
    field :query, :string
    field :variables, :string
    field :response_status, :integer
    field :response_data, :string
    field :errors, :string
    field :duration_ms, :integer
    field :ip_address, :string
    field :user_agent, :string
    field :request_id, :string
    field :inserted_at, non_null(:naive_datetime)
  end

  defp resolve_request_logs(_parent, args, _resolution) do
    query =
      RequestLog
      |> maybe_filter_user(args[:user_id])
      |> maybe_filter_operation(args[:operation_name])
      |> maybe_filter_status(args[:status])
      |> order_by([l], desc: l.inserted_at)
      |> limit(^args[:limit])

    logs = Repo.all(query)
    {:ok, logs}
  end

  defp maybe_filter_user(query, nil), do: query
  defp maybe_filter_user(query, user_id), do: where(query, [l], l.user_id == ^user_id)

  defp maybe_filter_operation(query, nil), do: query
  defp maybe_filter_operation(query, op), do: where(query, [l], l.operation_name == ^op)

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [l], l.response_status == ^status)
end
