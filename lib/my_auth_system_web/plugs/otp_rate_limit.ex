defmodule MyAuthSystemWeb.Plugs.OtpRateLimit do
  @moduledoc """
  Rate limiter for OTP verification to prevent brute force attacks.
  Tracks failed attempts per email and locks after threshold.
  """
  import Plug.Conn

  @max_attempts 5
  @lockout_duration 15 * 60 # 15 minutes in seconds

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only apply to OTP verification
    if is_otp_verification?(conn) do
      email = get_email_from_body(conn)
      
      case check_rate_limit(email) do
        :ok -> conn
        {:error, :locked} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(429, Jason.encode!(%{
            errors: [%{message: "Too many failed attempts. Please try again in 15 minutes."}]
          }))
          |> halt()
      end
    else
      conn
    end
  end

  defp is_otp_verification?(conn) do
    conn.request_path == "/api/graphql" &&
      conn.method == "POST"
  end

  defp get_email_from_body(conn) do
    # Extract email from GraphQL variables if present
    case conn.body_params do
      %{"variables" => %{"email" => email}} -> email
      _ -> nil
    end
  end

  defp check_rate_limit(nil), do: :ok
  defp check_rate_limit(email) do
    key = "otp_attempts:#{email}"
    now = System.system_time(:second)

    case :ets.lookup(:auth_rate_limit, key) do
      [] ->
        :ok

      [{^key, {attempts, first_attempt_time}}] ->
        if now - first_attempt_time > @lockout_duration do
          # Reset after lockout period
          :ets.delete(:auth_rate_limit, key)
          :ok
        else
          if attempts >= @max_attempts do
            {:error, :locked}
          else
            :ok
          end
        end
    end
  end

  @doc """
  Record a failed OTP attempt for an email.
  """
  def record_failed_attempt(email) when is_binary(email) do
    key = "otp_attempts:#{email}"
    now = System.system_time(:second)

    case :ets.lookup(:auth_rate_limit, key) do
      [] ->
        :ets.insert(:auth_rate_limit, {key, {1, now}})

      [{^key, {attempts, first_attempt_time}}] ->
        if now - first_attempt_time > @lockout_duration do
          # Reset after lockout period
          :ets.insert(:auth_rate_limit, {key, {1, now}})
        else
          :ets.insert(:auth_rate_limit, {key, {attempts + 1, first_attempt_time}})
        end
    end
  end

  def record_failed_attempt(_), do: :ok

  @doc """
  Clear failed attempts for an email (on successful verification).
  """
  def clear_attempts(email) when is_binary(email) do
    key = "otp_attempts:#{email}"
    :ets.delete(:auth_rate_limit, key)
  end

  def clear_attempts(_), do: :ok
end
