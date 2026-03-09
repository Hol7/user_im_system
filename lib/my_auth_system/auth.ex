defmodule MyAuthSystem.Auth do
  @moduledoc """
  The Auth context handles authentication, OTP, tokens, and password management.
  """

  alias MyAuthSystem.Repo
  alias MyAuthSystem.Accounts.User
  alias MyAuthSystem.Auth.{Otp, GuardianToken, RefreshToken}
  alias MyAuthSystem.Workers.EmailWorker
  import Ecto.Query

  @doc """
  Authenticate user with email and password.
  """
  def authenticate(email, password) do
    with %User{} = user <- Repo.get_by(User, email: email),
         true <-
           Argon2.verify_pass(password, user.password_hash) || {:error, :invalid_credentials} do
      {:ok, user}
    else
      false -> {:error, :invalid_credentials}
      nil -> {:error, :invalid_credentials}
      error -> error
    end
  end

  @doc """
  Generate OTP for user.
  Returns the OTP struct (code is already hashed in the struct).
  """
  def generate_otp(user_id, purpose) do
    Otp.generate_otp(user_id, purpose)
  end

  @doc """
  Generate tokens (access + refresh) for user.
  """
  def generate_tokens(user) do
    with {:ok, access_token, claims} <-
           GuardianToken.encode_and_sign(user, %{}, token_type: :access),
         refresh_token <- generate_refresh_token_string(),
         {:ok, _refresh_record} <- create_refresh_token(user.id, refresh_token, claims) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token}}
    end
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh_token(refresh_token_string) do
    with {:ok, refresh_record} <- verify_refresh_token(refresh_token_string),
         {:ok, user} <- Repo.get(User, refresh_record.user_id) |> validate_user(),
         {:ok, tokens} <- generate_tokens(user),
         :ok <- revoke_refresh_token(refresh_record.id) do
      {:ok, tokens}
    else
      {:error, :revoked} -> {:error, "Refresh token has been revoked"}
      {:error, :expired} -> {:error, "Refresh token has expired"}
      {:error, :invalid} -> {:error, "Invalid refresh token"}
      error -> error
    end
  end

  @doc """
  Request password reset - generates OTP and sends email.
  """
  def request_password_reset(email, otp_plain_code) do
    with {:ok, user} <- Repo.get_by(User, email: email) |> validate_user_for_reset(),
         otp <- Otp.generate_otp_with_code(user.id, :password_reset, otp_plain_code),
         {:ok, _saved_otp} <- Repo.insert(otp),
         :ok <- send_password_reset_email_async(user, otp_plain_code) do
      {:ok,
       %{message: "If an account exists for #{email}, you will receive a reset code shortly."}}
    else
      {:error, :user_not_found} ->
        {:ok,
         %{message: "If an account exists for #{email}, you will receive a reset code shortly."}}

      {:error, :account_inactive} ->
        {:ok,
         %{message: "If an account exists for #{email}, you will receive a reset code shortly."}}

      error ->
        error
    end
  end

  @doc """
  Reset password with OTP verification.
  """
  def reset_password(otp_id, code, new_password, new_password_confirmation) do
    with {:ok, otp} <- Repo.get(Otp, otp_id) |> Repo.preload(:user) |> validate_otp_for_reset(),
         {:ok, :valid} <- Otp.verify_otp(otp, code),
         true <- new_password == new_password_confirmation || {:error, :password_mismatch},
         {:ok, user} <- update_user_password(otp.user, new_password),
         :ok <- mark_otp_as_used(otp),
         :ok <- revoke_all_refresh_tokens(user.id) do
      # Log the action
      MyAuthSystem.Audit.Log.log_async(
        user.id,
        "PASSWORD_RESET",
        %{method: "otp", otp_id: otp_id},
        nil
      )

      {:ok, %{message: "Password successfully reset. Please login with your new password."}}
    else
      {:error, :already_used} -> {:error, "This reset code has already been used"}
      {:error, :expired} -> {:error, "This reset code has expired. Please request a new one."}
      {:error, :invalid} -> {:error, "Invalid reset code"}
      {:error, :password_mismatch} -> {:error, "New passwords do not match"}
      {:error, changeset} -> {:error, Ecto.Changeset.traverse_errors(changeset, & &1)}
      error -> error
    end
  end

  # === PRIVATE HELPERS ===

  defp validate_user(nil), do: {:error, :user_not_found}
  defp validate_user(%User{status: :active} = user), do: {:ok, user}
  defp validate_user(%User{status: :pending_verification} = user), do: {:ok, user}
  defp validate_user(_user), do: {:error, :account_inactive}

  defp validate_user_for_reset(nil), do: {:error, :user_not_found}
  defp validate_user_for_reset(%User{} = user), do: {:ok, user}

  defp validate_otp_for_reset(nil), do: {:error, :invalid_otp}
  defp validate_otp_for_reset(%Otp{purpose: :password_reset, used: false} = otp), do: {:ok, otp}
  defp validate_otp_for_reset(%Otp{used: true}), do: {:error, :already_used}
  defp validate_otp_for_reset(%Otp{}), do: {:error, :invalid_purpose}

  defp generate_refresh_token_string do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
  end

  defp create_refresh_token(user_id, token_string, claims) do
    expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

    %RefreshToken{
      user_id: user_id,
      token_hash: Argon2.hash_pwd_salt(token_string),
      expires_at: expires_at,
      user_agent: Map.get(claims, "user_agent", nil),
      ip_address: Map.get(claims, "ip_address", nil)
    }
    |> Repo.insert()
  end

  defp verify_refresh_token(token_string) do
    with %RefreshToken{} = token <-
           Repo.get_by(RefreshToken, token_hash: Argon2.hash_pwd_salt(token_string)),
         true <- !token.revoked || {:error, :revoked},
         true <-
           DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt || {:error, :expired} do
      {:ok, token}
    else
      false -> {:error, :invalid}
      nil -> {:error, :invalid}
      error -> error
    end
  end

  defp revoke_refresh_token(token_id) do
    Repo.update_all(from(rt in RefreshToken, where: rt.id == ^token_id), set: [revoked: true])
    :ok
  end

  defp revoke_all_refresh_tokens(user_id) do
    Repo.update_all(from(rt in RefreshToken, where: rt.user_id == ^user_id), set: [revoked: true])
    :ok
  end

  defp send_password_reset_email_async(user, otp_code) do
    EmailWorker.new(%{
      type: "password_reset",
      email: user.email,
      name: user.profile.first_name || "User",
      otp: otp_code
    })
    |> Oban.insert()
  end

  defp update_user_password(user, new_password) do
    user
    |> Ecto.Changeset.change(%{
      password: new_password,
      password_confirmation: new_password
    })
    |> User.registration_changeset(%{})
    |> Repo.update()
  end

  defp mark_otp_as_used(otp) do
    otp
    |> Ecto.Changeset.change(used: true)
    |> Repo.update()
    |> case do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end
end
