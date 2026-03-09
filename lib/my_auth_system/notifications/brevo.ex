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
    # api_key = System.fetch_env!("BREVO_API_KEY")
    # sender_name = System.get_env("BREVO_SENDER_NAME", "MyAuth System")
    # sender_email = System.get_env("BREVO_SENDER_EMAIL", "noreply@myauthsystem.com")
    api_key = config.api_key
    sender_name = config.sender_name
    sender_email = config.email

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
  Envoie l'email de bienvenue avec lien de validation.
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
