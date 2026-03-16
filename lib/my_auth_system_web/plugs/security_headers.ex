defmodule MyAuthSystemWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds security headers to responses.
  Follows OWASP Secure Headers Project recommendations.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'"
    )
    |> put_resp_header(
      "permissions-policy",
      "geolocation=(), microphone=(), camera=(), payment=()"
    )
  end
end
