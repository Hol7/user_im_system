defmodule MyAuthSystemWeb.ConsoleLogsLive do
  @moduledoc """
  LiveView page to show real-time console logs similar to mix phx.server output.
  This uses Logger backend to capture and display logs.
  """
  use Phoenix.LiveView
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to telemetry events for real-time updates
      :telemetry.attach(
        "console-logs-#{inspect(self())}",
        [:phoenix, :endpoint, :stop],
        &handle_telemetry_event/4,
        socket.assigns
      )
    end

    {:ok, assign(socket, logs: [], max_logs: 100)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="console-logs">
      <h1>Console Logs (Live)</h1>
      <div class="controls">
        <button phx-click="clear">Clear Logs</button>
        <button phx-click="refresh">Refresh</button>
      </div>

      <div class="log-container" style="background: #1e1e1e; color: #d4d4d4; padding: 20px; font-family: 'Courier New', monospace; height: 80vh; overflow-y: auto;">
        <%= for log <- @logs do %>
          <div class={"log-entry log-#{log.level}"}>
            <span class="timestamp"><%= log.timestamp %></span>
            <span class="level"><%= format_level(log.level) %></span>
            <span class="message"><%= log.message %></span>
          </div>
        <% end %>
      </div>
    </div>

    <style>
      .log-entry { margin: 5px 0; }
      .log-info { color: #4ec9b0; }
      .log-debug { color: #9cdcfe; }
      .log-warning { color: #dcdcaa; }
      .log-error { color: #f48771; }
      .timestamp { color: #808080; margin-right: 10px; }
      .level { font-weight: bold; margin-right: 10px; }
    </style>
    """
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, logs: [])}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:log, log_entry}, socket) do
    logs = [log_entry | socket.assigns.logs] |> Enum.take(socket.assigns.max_logs)
    {:noreply, assign(socket, logs: logs)}
  end

  defp handle_telemetry_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    # This will be called for each request
    log_entry = %{
      timestamp: format_timestamp(System.system_time(:millisecond)),
      level: :info,
      message: format_request(metadata, measurements)
    }

    send(self(), {:log, log_entry})
  end

  defp format_timestamp(ms) do
    DateTime.from_unix!(ms, :millisecond)
    |> Calendar.strftime("%H:%M:%S.%f")
    |> String.slice(0..-4//-1)
  end

  defp format_level(:info), do: "[info]"
  defp format_level(:debug), do: "[debug]"
  defp format_level(:warning), do: "[warning]"
  defp format_level(:error), do: "[error]"

  defp format_request(metadata, measurements) do
    method = metadata[:method] || "GET"
    path = metadata[:request_path] || "/"
    status = metadata[:status] || 200
    duration = div(measurements[:duration], 1_000_000) # Convert to ms

    "#{method} #{path} - Sent #{status} in #{duration}ms"
  end
end
