defmodule MyAuthSystemWeb.RequestLogsLive do
  use Phoenix.LiveView
  import Ecto.Query
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Monitoring.RequestLog

  @impl true
  def mount(_params, _session, socket) do
    logs = fetch_logs(50, nil, :inserted_at, :desc)

    {:ok, assign(socket,
      logs: logs,
      search: "",
      limit: 50,
      sort_by: :inserted_at,
      sort_dir: :desc
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="request-logs-container" style="padding: 20px;">
      <h1>GraphQL Request Logs</h1>

      <div class="controls" style="margin: 20px 0;">
        <form phx-submit="search" style="display: inline-block;">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search operation or user..."
            style="padding: 8px; width: 300px; border: 1px solid #ccc; border-radius: 4px;"
          />
          <button type="submit" style="padding: 8px 16px; margin-left: 10px; background: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Search
          </button>
        </form>

        <button phx-click="refresh" style="padding: 8px 16px; margin-left: 10px; background: #2196F3; color: white; border: none; border-radius: 4px; cursor: pointer;">
          Refresh
        </button>

        <select phx-change="change_limit" name="limit" style="padding: 8px; margin-left: 10px; border: 1px solid #ccc; border-radius: 4px;">
          <option value="50" selected={@limit == 50}>50 logs</option>
          <option value="100" selected={@limit == 100}>100 logs</option>
          <option value="200" selected={@limit == 200}>200 logs</option>
        </select>
      </div>

      <table style="width: 100%; border-collapse: collapse; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <thead>
          <tr style="background: #f5f5f5; border-bottom: 2px solid #ddd;">
            <th phx-click="sort" phx-value-field="inserted_at" style="padding: 12px; text-align: left; cursor: pointer;">
              Time <%= sort_indicator(@sort_by, @sort_dir, :inserted_at) %>
            </th>
            <th style="padding: 12px; text-align: left;">Operation</th>
            <th style="padding: 12px; text-align: left;">User</th>
            <th phx-click="sort" phx-value-field="duration_ms" style="padding: 12px; text-align: left; cursor: pointer;">
              Duration <%= sort_indicator(@sort_by, @sort_dir, :duration_ms) %>
            </th>
            <th style="padding: 12px; text-align: left;">Status</th>
            <th style="padding: 12px; text-align: left;">Errors</th>
          </tr>
        </thead>
        <tbody>
          <%= for log <- @logs do %>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 12px;"><%= format_time(log.inserted_at) %></td>
              <td style="padding: 12px;"><%= log.operation_name || "anonymous" %></td>
              <td style="padding: 12px; font-family: monospace; font-size: 12px;"><%= format_user(log.user_id) %></td>
              <td style="padding: 12px;"><%= format_duration(log.duration_ms) %></td>
              <td style="padding: 12px;"><%= format_status(log.response_status) %></td>
              <td style="padding: 12px;"><%= format_errors(log.errors) %></td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <%= if Enum.empty?(@logs) do %>
        <p style="text-align: center; padding: 40px; color: #999;">No logs found</p>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    logs = fetch_logs(socket.assigns.limit, search, socket.assigns.sort_by, socket.assigns.sort_dir)
    {:noreply, assign(socket, logs: logs, search: search)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    logs = fetch_logs(socket.assigns.limit, socket.assigns.search, socket.assigns.sort_by, socket.assigns.sort_dir)
    {:noreply, assign(socket, logs: logs)}
  end

  @impl true
  def handle_event("change_limit", %{"limit" => limit}, socket) do
    limit = String.to_integer(limit)
    logs = fetch_logs(limit, socket.assigns.search, socket.assigns.sort_by, socket.assigns.sort_dir)
    {:noreply, assign(socket, logs: logs, limit: limit)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)
    sort_dir = if socket.assigns.sort_by == field and socket.assigns.sort_dir == :desc, do: :asc, else: :desc
    logs = fetch_logs(socket.assigns.limit, socket.assigns.search, field, sort_dir)
    {:noreply, assign(socket, logs: logs, sort_by: field, sort_dir: sort_dir)}
  end

  defp fetch_logs(limit, search, sort_by, sort_dir) do
    RequestLog
    |> maybe_search(search)
    |> order_by(^build_order(sort_by, sort_dir))
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query
  defp maybe_search(query, search) do
    search_term = "%#{search}%"
    where(query, [l],
      ilike(l.operation_name, ^search_term) or
      fragment("?::text ILIKE ?", l.user_id, ^search_term)
    )
  end

  defp build_order(:inserted_at, :desc), do: [desc: :inserted_at]
  defp build_order(:inserted_at, :asc), do: [asc: :inserted_at]
  defp build_order(:duration_ms, :desc), do: [desc: :duration_ms]
  defp build_order(:duration_ms, :asc), do: [asc: :duration_ms]
  defp build_order(_, _), do: [desc: :inserted_at]

  defp sort_indicator(current_field, current_dir, field) do
    if current_field == field do
      if current_dir == :desc, do: "▼", else: "▲"
    else
      ""
    end
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_user(nil), do: "anonymous"
  defp format_user(user_id), do: String.slice(to_string(user_id), 0..7) <> "..."

  defp format_duration(ms) when is_integer(ms), do: "#{ms}ms"
  defp format_duration(_), do: "-"

  defp format_status(200), do: "✅ 200"
  defp format_status(400), do: "⚠️ 400"
  defp format_status(500), do: "❌ 500"
  defp format_status(status), do: to_string(status)

  defp format_errors(nil), do: "-"
  defp format_errors(%{"errors" => errors}) when is_list(errors), do: "#{length(errors)} error(s)"
  defp format_errors(_), do: "Error"
end
