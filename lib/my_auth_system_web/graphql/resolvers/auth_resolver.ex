defmodule MyAuthSystemWeb.GraphQL.Resolvers.AuthResolver do
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Accounts
  alias MyAuthSystem.Auth
  alias MyAuthSystem.Auth.Otp
  alias MyAuthSystem.Workers.EmailWorker

  @doc """
  Mutation: register(input: RegisterInput!)
  """
  def register(_parent, %{input: input}, _resolution) do
    # Generate plain text OTP BEFORE inserting (so we can email it)
    otp_plain_code = generate_otp_code()

    with {:ok, user} <- Accounts.create_user(input),
         {:ok, _profile} <- Accounts.create_profile(user, input),
         otp <- Otp.generate_otp_with_code(user.id, :email_verification, otp_plain_code),
         # ✅ FIXED: Prefix with underscore
         {:ok, _saved_otp} <- Repo.insert(otp) do
      # Send welcome/verification email async
      EmailWorker.new(%{
        type: "welcome",
        email: user.email,
        name: input.first_name,
        otp: otp_plain_code
      })
      |> Oban.insert()

      {:ok, %{user: user, token: nil, message: "Verification email sent"}}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      error -> error
    end
  end

  @doc """
  Mutation: login(email: String!, password: String!)
  """
  def login(_parent, %{email: email, password: password}, _resolution) do
    # Generate plain text OTP BEFORE inserting
    otp_plain_code = generate_otp_code()

    with {:ok, user} <- Auth.authenticate(email, password),
         true <- user.status in [:active, :pending_verification] || {:error, :account_inactive},
         otp <- Otp.generate_otp_with_code(user.id, :login, otp_plain_code),
         # ✅ KEPT: This one IS used below
         {:ok, saved_otp} <- Repo.insert(otp) do
      # Send OTP email async
      EmailWorker.new(%{
        type: "otp",
        email: user.email,
        name: user.profile.first_name || "User",
        otp: otp_plain_code
      })
      |> Oban.insert()

      # ✅ Used here
      {:ok, %{message: "OTP sent to your email", otp_id: saved_otp.id}}
    else
      {:error, :invalid_credentials} -> {:error, "Invalid email or password"}
      {:error, :account_inactive} -> {:error, "Account is not active"}
      error -> error
    end
  end

  @doc """
  Mutation: verifyOtp(otpId: ID!, code: String!)
  """
  def verify_otp(_parent, %{otp_id: otp_id, code: code}, _resolution) do
    with {:ok, otp} <- Repo.get(Otp, otp_id) |> Repo.preload(:user) |> validate_otp(),
         {:ok, :valid} <- Otp.verify_otp(otp, code),
         {:ok, tokens} <- Auth.generate_tokens(otp.user) do
      # Mark OTP as used
      otp
      |> Ecto.Changeset.change(used: true)
      |> Repo.update()

      # Log the action
      MyAuthSystem.Audit.Log.log_async(
        otp.user_id,
        "LOGIN_SUCCESS",
        %{method: "otp"},
        nil
      )

      {:ok, %{user: otp.user, token: tokens.access_token, refresh_token: tokens.refresh_token}}
    else
      {:error, reason} -> {:error, "Invalid or expired OTP: #{inspect(reason)}"}
    end
  end

  #   @doc """
  # Mutation: requestPasswordReset(email: String!)
  # """
  # def request_password_reset(_parent, %{email: email}, _resolution) do
  #   case MyAuthSystem.Auth.request_password_reset(email) do
  #     {:ok, result} -> {:ok, result}
  #     {:error, message} -> {:error, message}
  #   end
  # end

  # @doc """
  # Mutation: resetPassword(otpId: ID!, code: String!, newPassword: String!, newPasswordConfirmation: String!)
  # """
  # def reset_password(_parent, %{otp_id: otp_id, code: code, new_password: new_pass, new_password_confirmation: new_pass_conf}, _resolution) do
  #   case MyAuthSystem.Auth.reset_password(otp_id, code, new_pass, new_pass_conf) do
  #     {:ok, result} -> {:ok, result}
  #     {:error, message} -> {:error, message}
  #   end
  # end

  @doc """
  Mutation: requestPasswordReset(email: String!)
  """
  def request_password_reset(_parent, %{email: email}, _resolution) do
    otp_plain_code = generate_otp_code()

    case Auth.request_password_reset(email, otp_plain_code) do
      {:ok, result} -> {:ok, result}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Mutation: resetPassword(otpId: ID!, code: String!, newPassword: String!, newPasswordConfirmation: String!)
  """
  def reset_password(
        _parent,
        %{
          otp_id: otp_id,
          code: code,
          new_password: new_pass,
          new_password_confirmation: new_pass_conf
        },
        _resolution
      ) do
    case Auth.reset_password(otp_id, code, new_pass, new_pass_conf) do
      {:ok, result} -> {:ok, result}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Mutation: refreshToken(refreshToken: String!)
  """
  def refresh_token(_parent, %{refresh_token: token}, _resolution) do
    case Auth.refresh_token(token) do
      {:ok, user, new_access_token, new_refresh_token} ->
        {:ok, %{user: user, token: new_access_token, refresh_token: new_refresh_token, message: "Token refreshed"}}
      {:error, message} ->
        {:error, message}
    end
  end

  # === PRIVATE HELPERS ===

  defp generate_otp_code do
    :crypto.strong_rand_bytes(3)
    |> :binary.bin_to_list()
    |> Enum.map(&rem(&1, 10))
    |> Enum.join()
  end

  defp validate_otp(nil), do: {:error, :invalid_otp}
  defp validate_otp(otp), do: {:ok, otp}

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
