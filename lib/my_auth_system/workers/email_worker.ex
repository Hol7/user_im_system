defmodule MyAuthSystem.Workers.EmailWorker do
  @moduledoc """
  Worker Oban pour envoyer des emails via Brevo de manière asynchrone.
  """
  use Oban.Worker, queue: :emails, max_attempts: 3

  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"type" => "otp", "email" => email, "name" => name, "otp" => otp}}) do
    case MyAuthSystem.Notifications.Brevo.send_otp_email(email, name, otp) do
      {:ok, _response} -> :ok
      {:error, error} -> {:retry, error}
    end
  end

  def perform(%Oban.Job{args: %{"type" => "welcome", "email" => _email, "name" => _name}}) do
    # Implémenter email de bienvenue si besoin
    :ok
  end

  def perform(%Oban.Job{
        args: %{"type" => "password_reset", "email" => email, "name" => name, "otp" => otp}
      }) do
    case MyAuthSystem.Notifications.Brevo.send_password_reset_email(email, name, otp) do
      {:ok, _response} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to send password reset email: #{inspect(error)}")
        {:retry, error}
    end
  end
end
