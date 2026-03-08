defmodule MyAuthSystem.Notifications.Brevo do
  @moduledoc """
  Service d'envoi d'emails via l'API Brevo (Sendinblue).
  Utilise Finch pour des requêtes HTTP asynchrones et performantes.
  """

  @base_url "https://api.brevo.com/v3/smtp/email"
  @api_key System.fetch_env!("BREVO_API_KEY")
  @sender_name System.get_env("BREVO_SENDER_NAME", "MyAuth System")
  @sender_email System.get_env("BREVO_SENDER_EMAIL", "noreply@myauthsystem.com")

  @doc """
  Envoie un email HTML via Brevo.
  """
  def send_email(to_email, to_name, subject, html_content, headers \\ %{}) do
    payload = %{
      sender: %{
        name: @sender_name,
        email: @sender_email
      },
      to: [
        %{email: to_email, name: to_name}
      ],
      subject: subject,
      htmlContent: html_content,
      headers: Map.merge(%{"charset" => "iso-8859-1"}, headers)
    }

    Finch.build(:post, @base_url)
    |> Finch.put_req_header("accept", "application/json")
    |> Finch.put_req_header("api-key", @api_key)
    |> Finch.put_req_header("content-type", "application/json")
    |> Finch.put_req_body!(Jason.encode!(payload))
    |> Finch.request(MyAuthSystem.Finch)
    |> case do
      {:ok, %Finch.Response{status: 201, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, %{status: status, body: body, message: "Brevo API error"}}

      {:error, reason} ->
        {:error, %{reason: reason, message: "HTTP request failed"}}
    end
  end

  @doc """
  Envoie l'email d'OTP de connexion (format spécifique demandé).
  """
  def send_otp_email(user_email, user_name, otp_code) do
    html_content = """
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; }
          .otp-code { font-size: 24px; font-weight: bold; letter-spacing: 5px; color: #2c3e50; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <h2>Hello #{user_name},</h2>
          <p>Your login verification code is:</p>
          <p class="otp-code">#{otp_code}</p>
          <p>This code will expire in 5 minutes.</p>
          <p>If you didn't request this code, please ignore this email.</p>
        </div>
      </body>
    </html>
    """

    send_email(
      user_email,
      user_name,
      "Your Login Verification Code",
      html_content,
      %{"X-Mailin-custom" => "purpose:otp_login|priority:high"}
    )
  end

  @doc """
  Envoie l'email de réinitialisation de mot de passe avec code OTP.
  """
  def send_password_reset_email(user_email, user_name, otp_code) do
    html_content = """
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .otp-code {
            font-size: 28px;
            font-weight: bold;
            letter-spacing: 8px;
            color: #e74c3c;
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            display: inline-block;
            margin: 20px 0;
          }
          .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 12px;
            margin: 20px 0;
            font-size: 14px;
          }
          .footer { font-size: 12px; color: #666; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <h2>Password Reset Request 🔐</h2>
          <p>Hello #{user_name},</p>
          <p>We received a request to reset the password for your account associated with <strong>#{user_email}</strong>.</p>

          <p>Use the verification code below to proceed with resetting your password:</p>

          <div class="otp-code">#{otp_code}</div>

          <p>This code is valid for <strong>10 minutes</strong>.</p>

          <div class="warning">
            <strong>⚠️ Security Notice:</strong> If you didn't request this password reset, please ignore this email or contact our support team immediately. Your account remains secure.
          </div>

          <p>For security reasons, this code can only be used once.</p>

          <div class="footer">
            <p>© 2026 MyAuth System. All rights reserved.</p>
            <p>Need help? <a href="mailto:support@myauthsystem.com">Contact Support</a></p>
            <p>This is an automated message, please do not reply directly to this email.</p>
          </div>
        </div>
      </body>
    </html>
    """

    send_email(
      user_email,
      user_name,
      "Password Reset Verification Code",
      html_content,
      %{
        "X-Mailin-custom" => "purpose:password_reset|priority:high",
        "X-Priority" => "1"
      }
    )
  end
end
