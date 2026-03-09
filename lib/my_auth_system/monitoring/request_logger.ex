defmodule MyAuthSystem.Monitoring.RequestLogger do
  @moduledoc """
  Telemetry handler for logging all GraphQL requests and responses.
  """
  require Logger
  alias MyAuthSystem.Monitoring.RequestLog
  alias MyAuthSystem.Repo

  def attach do
    :telemetry.attach(
      "graphql-request-logger",
      [:absinthe, :execute, :operation, :stop],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:absinthe, :execute, :operation, :stop], measurements, metadata, _config) do
    # Extract request details
    operation_name = get_in(metadata, [:blueprint, :name])
    query = extract_query(metadata)
    variables = get_in(metadata, [:options, :variables]) || %{}

    # Extract response details
    result = metadata[:result]
    {response_status, response_data, errors} = parse_result(result)

    # Extract user context
    user_id = get_in(metadata, [:options, :context, :current_user, :id])

    # Duration in milliseconds
    duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

    # Build log entry
    attrs = %{
      user_id: user_id,
      operation_name: operation_name,
      query: query,
      variables: sanitize_variables(variables),
      response_status: response_status,
      response_data: sanitize_response(response_data),
      errors: errors,
      duration_ms: duration_ms,
      request_id: Logger.metadata()[:request_id]
    }

    # Async insert to avoid blocking
    Task.start(fn ->
      %RequestLog{}
      |> RequestLog.changeset(attrs)
      |> Repo.insert()
    end)

    # Also log to console for immediate visibility
    log_level = if errors, do: :warning, else: :info

    Logger.log(log_level, """
    GraphQL Request: #{operation_name || "anonymous"}
    Duration: #{duration_ms}ms
    Status: #{response_status}
    User: #{user_id || "anonymous"}
    #{if errors, do: "Errors: #{inspect(errors)}", else: ""}
    """)
  end

  defp extract_query(metadata) do
    case get_in(metadata, [:blueprint, :input]) do
      nil -> get_in(metadata, [:options, :document]) || "N/A"
      input when is_binary(input) -> String.slice(input, 0, 5000)
      _ -> "N/A"
    end
  end

  defp parse_result({:ok, %{data: data, errors: errors}}) do
    {200, data, format_errors(errors)}
  end

  defp parse_result({:ok, %{data: data}}) do
    {200, data, nil}
  end

  defp parse_result({:ok, %{errors: errors}}) do
    {400, nil, format_errors(errors)}
  end

  defp parse_result({:error, error}) do
    {500, nil, %{message: inspect(error)}}
  end

  defp parse_result(_) do
    {200, nil, nil}
  end

  defp format_errors(nil), do: nil
  defp format_errors([]), do: nil

  defp format_errors(errors) when is_list(errors) do
    %{errors: Enum.map(errors, &Map.take(&1, [:message, :path, :locations]))}
  end

  defp sanitize_variables(variables) when is_map(variables) do
    variables
    |> Map.drop(["password", "passwordConfirmation", "currentPassword", "newPassword"])
    |> Enum.into(%{}, fn {k, v} ->
      if k in ["password", "passwordConfirmation", "currentPassword", "newPassword"] do
        {k, "[REDACTED]"}
      else
        {k, v}
      end
    end)
  end

  defp sanitize_variables(variables), do: variables

  defp sanitize_response(nil), do: nil

  defp sanitize_response(data) when is_map(data) do
    # Limit response size to prevent huge logs
    data
    |> Jason.encode!()
    |> String.slice(0, 10_000)
    |> Jason.decode!()
  rescue
    _ -> %{truncated: true}
  end

  defp sanitize_response(data), do: data
end
