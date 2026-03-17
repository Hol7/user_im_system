defmodule MyAuthSystem.Auth do
  @moduledoc """
  The Auth context handles authentication, OTP, tokens, and password management.
  """

  alias MyAuthSystem.Repo
  alias MyAuthSystem.Accounts.User
  alias MyAuthSystem.Auth.{Otp, GuardianToken, RefreshToken, PasswordResetToken}
  alias MyAuthSystem.Workers.EmailWorker
  import Ecto.Query

  @doc """
  Authenticate user with email and password.
  Includes login rate limiting per OWASP recommendations.
  """
  def authenticate(email, password) do
    # Check rate limit first
    with :ok <- MyAuthSystemWeb.Plugs.LoginRateLimit.check_login_attempt(email),
         %User{} = user <- Repo.get_by(User, email: email),
         :ok <- check_user_status(user),
         true <-
           Argon2.verify_pass(password, user.password_hash) || {:error, :invalid_credentials} do
      # Clear failed attempts on successful login
      MyAuthSystemWeb.Plugs.LoginRateLimit.clear_login_attempts(email)
      {:ok, user}
    else
      false ->
        MyAuthSystemWeb.Plugs.LoginRateLimit.record_failed_login(email)
        {:error, :invalid_credentials}
      nil ->
        MyAuthSystemWeb.Plugs.LoginRateLimit.record_failed_login(email)
        {:error, :invalid_credentials}
      {:error, reason} when is_binary(reason) ->
        {:error, reason}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_user_status(%User{status: :archived}), do: {:error, "Account archived. Please contact kp-support for assistance."}
  defp check_user_status(%User{status: :suspended}), do: {:error, "Account suspended. Please contact support."}
  defp check_user_status(%User{status: :deletion_requested}), do: {:error, "Account deletion in progress."}
  defp check_user_status(%User{status: :active}), do: :ok
  defp check_user_status(%User{status: :pending_verification}), do: :ok

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
      {:ok, %{user: user, access_token: tokens.access_token, refresh_token: tokens.refresh_token}}
    else
      {:error, :revoked} -> {:error, "Refresh token has been revoked"}
      {:error, :expired} -> {:error, "Refresh token has expired"}
      {:error, :invalid} -> {:error, "Invalid refresh token"}
      error -> error
    end
  end

  @doc """
  Request password reset with secure token link (OWASP recommended).
  Generates cryptographically secure token and sends email with reset link.
  """
  def request_password_reset_link(email) do
    with {:ok, user} <- Repo.get_by(User, email: email) |> validate_user_for_reset(),
         {plain_token, token_struct} <- PasswordResetToken.create_for_user(user.id),
         {:ok, _saved_token} <- Repo.insert(token_struct),
         :ok <- send_password_reset_link_email(user, plain_token) do
      {:ok, %{message: "If an account exists for #{email}, you will receive a password reset link shortly."}}
    else
      {:error, :user_not_found} ->
        {:ok, %{message: "If an account exists for #{email}, you will receive a password reset link shortly."}}
      {:error, :account_inactive} ->
        {:ok, %{message: "If an account exists for #{email}, you will receive a password reset link shortly."}}
      error -> error
    end
  end

  @doc """
  Request password reset - generates OTP and sends email (legacy method).
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
  Logout user by revoking refresh token.
  Follows RFC 7009 - OAuth 2.0 Token Revocation standard.
  """
  def logout(user_id, refresh_token_string) do
    with {:ok, refresh_record} <- verify_refresh_token(refresh_token_string),
         true <- refresh_record.user_id == user_id || {:error, "Token does not belong to user"},
         :ok <- revoke_refresh_token(refresh_record.id) do

      MyAuthSystem.Audit.Log.log_async(
        user_id,
        "user_logout",
        %{token_id: refresh_record.id},
        nil
      )

      {:ok, "Successfully logged out"}
    else
      {:error, :invalid} -> {:error, "Invalid refresh token"}
      {:error, :revoked} -> {:error, "Token already revoked"}
      {:error, :expired} -> {:error, "Token expired"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Reset password with OTP verification.
  """
  def reset_password(otp_id, code, new_password, new_password_confirmation) do
    try do
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
    rescue
      Ecto.Query.CastError -> {:error, "Invalid reset code ID format"}
      _ -> {:error, "Invalid or expired reset code"}
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
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(7, :day)
      |> DateTime.truncate(:second)

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
    # Get all non-revoked, non-expired tokens and verify hash in memory
    # This is necessary because Argon2 generates different hashes each time
    query =
      from rt in RefreshToken,
        where: rt.revoked == false,
        where: rt.expires_at > ^DateTime.utc_now(),
        order_by: [desc: rt.inserted_at],
        limit: 100

    tokens = Repo.all(query)

    matching_token =
      Enum.find(tokens, fn token ->
        Argon2.verify_pass(token_string, token.token_hash)
      end)

    case matching_token do
      nil -> {:error, :invalid}
      token -> {:ok, token}
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

  defp send_password_reset_link_email(user, reset_token) do
    user = Repo.preload(user, :profile)

    name = case user.profile do
      %{first_name: first_name} when is_binary(first_name) and first_name != "" -> first_name
      _ -> "User"
    end

    app_url = System.get_env("APP_URL", "http://localhost:4000")
    reset_link = "#{app_url}/reset-password?token=#{reset_token}"

    EmailWorker.new(%{
      type: "password_reset_link",
      email: user.email,
      name: name,
      reset_link: reset_link
    }, priority: 0)
    |> Oban.insert()

    :ok
  end

  defp send_password_reset_email_async(user, otp_code) do
    user = Repo.preload(user, :profile)

    name =
      case user.profile do
        %{first_name: first_name} when is_binary(first_name) and first_name != "" -> first_name
        _ -> "User"
      end

    EmailWorker.new(%{
      type: "password_reset",
      email: user.email,
      name: name,
      otp: otp_code
    })
    |> Oban.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
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
