defmodule MyAuthSystem.Notifications.Brevo do
  @moduledoc """
  Service d'envoi d'emails via l'API Brevo.
  """

  @base_url "https://api.brevo.com/v3/smtp/email"
  # ❌ REMOVE: @api_key System.fetch_env!("BREVO_API_KEY")

  @doc """
  Envoie un email HTML via Brevo.
  """
  def send_email(to_email, to_name, subject, html_content, headers \\ %{}) do
    # ✅ FETCH AT RUNTIME inside the function
    config = Application.fetch_env!(:my_auth_system, :brevo)
    api_key = Keyword.get(config, :api_key)
    sender_name = Keyword.get(config, :sender_name, "MyAuth System")
    sender_email = Keyword.get(config, :sender_email, "noreply@myauthsystem.com")

    if is_nil(api_key) or api_key == "" do
      raise "BREVO_API_KEY is not configured. Please set it in your .env file or environment variables."
    end

    payload = %{
      sender: %{name: sender_name, email: sender_email},
      to: [%{email: to_email, name: to_name}],
      subject: subject,
      htmlContent: html_content,
      headers: Map.merge(%{"charset" => "iso-8859-1"}, headers)
    }

    Req.post(@base_url,
      headers: [
        {"accept", "application/json"},
        {"api-key", api_key},
        {"content-type", "application/json"}
      ],
      json: payload
    )
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: 201, body: body}}),
    do: {:ok, body}

  defp handle_response({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, %{status: status, body: body}}

  defp handle_response({:error, reason}),
    do: {:error, %{reason: reason}}

  @doc """
  Envoie l'email d'OTP de connexion.
  """
  def send_otp_email(user_email, user_name, otp_code) do
    html_content = """
    <html><body><h1>Your code: #{otp_code}</h1></body></html>
    """

    send_email(user_email, user_name, "Your Login Code", html_content, %{
      "X-Mailin-custom" => "purpose:otp_login"
    })
  end

  @doc """
  Envoie l'email de vérification de compte avec code OTP.
  """
  def send_verification_email(user_email, user_name, otp_code) do
    html_content = """
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px;">
      <h1>Welcome to MyAuth System!</h1>
      <p>Hi #{user_name},</p>
      <p>Thank you for registering. Please verify your email address using the code below:</p>
      <div style="background-color: #f4f4f4; padding: 15px; margin: 20px 0; text-align: center;">
        <h2 style="color: #333; letter-spacing: 5px;">#{otp_code}</h2>
      </div>
      <p>This code will expire in 5 minutes.</p>
      <p>If you didn't create this account, please ignore this email.</p>
    </body>
    </html>
    """

    send_email(user_email, user_name, "Verify Your Email - MyAuth System", html_content, %{
      "X-Mailin-custom" => "purpose:email_verification"
    })
  end

  @doc """
  Envoie l'email de bienvenue avec lien de validation (legacy).
  """
  def send_welcome_email(user_email, user_name, validation_token) do
    app_url = System.get_env("APP_URL", "http://localhost:4000")
    validation_link = "#{app_url}/api/auth/validate-email?token=#{validation_token}"

    html_content = """
    <html><body><h1>Welcome! Verify: <a href="#{validation_link}">Click here</a></h1></body></html>
    """

    send_email(user_email, user_name, "Welcome! Verify your email", html_content)
  end

  @doc """
  Envoie l'email de réinitialisation de mot de passe.
  """
  def send_password_reset_email(user_email, user_name, otp_code) do
    html_content = """
    <html><body><h1>Reset code: #{otp_code}</h1></body></html>
    """

    send_email(user_email, user_name, "Password Reset", html_content, %{
      "X-Priority" => "1"
    })
  end
end
