defmodule MyAuthSystemWeb.Plugs.LoginRateLimit do
  @moduledoc """
  Rate limiter for login attempts per email address.
  Follows OWASP Authentication Cheat Sheet recommendations.
  Tracks failed login attempts and locks account temporarily after threshold.
  """

  @max_attempts 5
  @lockout_duration 900 # 15 minutes in seconds
  @ets_table :auth_rate_limit

  @doc """
  Check if login attempt is allowed for this email.
  Returns :ok or {:error, :locked}.
  """
  def check_login_attempt(email) when is_binary(email) do
    key = "login_attempts:#{email}"
    now = System.system_time(:second)

    case :ets.lookup(@ets_table, key) do
      [] ->
        :ok

      [{^key, {attempts, first_attempt_time}}] ->
        if now - first_attempt_time > @lockout_duration do
          # Reset after lockout period
          :ets.delete(@ets_table, key)
          :ok
        else
          if attempts >= @max_attempts do
            remaining_time = @lockout_duration - (now - first_attempt_time)
            {:error, "Too many failed login attempts. Account locked for #{div(remaining_time, 60)} more minutes."}
          else
            :ok
          end
        end
    end
  end

  def check_login_attempt(_), do: :ok

  @doc """
  Record a failed login attempt for an email.
  """
  def record_failed_login(email) when is_binary(email) do
    key = "login_attempts:#{email}"
    now = System.system_time(:second)

    case :ets.lookup(@ets_table, key) do
      [] ->
        :ets.insert(@ets_table, {key, {1, now}})

      [{^key, {attempts, first_attempt_time}}] ->
        if now - first_attempt_time > @lockout_duration do
          # Reset after lockout period
          :ets.insert(@ets_table, {key, {1, now}})
        else
          :ets.insert(@ets_table, {key, {attempts + 1, first_attempt_time}})

          # Send email notification if account is now locked
          if attempts + 1 == @max_attempts do
            send_lockout_notification(email)
          end
        end
    end
  end

  def record_failed_login(_), do: :ok

  @doc """
  Clear failed login attempts for an email (on successful login).
  """
  def clear_login_attempts(email) when is_binary(email) do
    key = "login_attempts:#{email}"
    :ets.delete(@ets_table, key)
  end

  def clear_login_attempts(_), do: :ok

  defp send_lockout_notification(email) do
    # Optional: Send email notification about account lockout
    # For now, just log it
    require Logger
    Logger.warning("Account locked due to failed login attempts: #{email}")
  end
end
