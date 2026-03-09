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
      {:error, reason} when is_atom(reason) -> {:error, Atom.to_string(reason)}
      {:error, reason} -> {:error, inspect(reason)}
      error -> {:error, inspect(error)}
    end
  end

  @doc """
  Mutation: login(email: String!, password: String!)
  """
  def login(_parent, %{email: email, password: password}, _resolution) do
    # Generate plain text OTP BEFORE inserting
    otp_plain_code = generate_otp_code()

    with {:ok, user} <- Auth.authenticate(email, password),
         user <- Repo.preload(user, :profile),
         true <- user.status in [:active, :pending_verification] || {:error, :account_inactive},
         otp <- Otp.generate_otp_with_code(user.id, :login, otp_plain_code),
         # ✅ KEPT: This one IS used below
         {:ok, saved_otp} <- Repo.insert(otp) do
      # Send OTP email async
      name =
        case user.profile do
          %{first_name: first_name} when is_binary(first_name) and first_name != "" -> first_name
          _ -> "User"
        end

      EmailWorker.new(%{
        type: "otp",
        email: user.email,
        name: name,
        otp: otp_plain_code
      })
      |> Oban.insert()

      # ✅ Used here
      {:ok, %{message: "OTP sent to your email", otp_id: saved_otp.id}}
    else
      {:error, :invalid_credentials} -> {:error, "Invalid email or password"}
      {:error, :account_inactive} -> {:error, "Account is not active"}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} when is_atom(reason) -> {:error, Atom.to_string(reason)}
      {:error, reason} -> {:error, inspect(reason)}
      error -> {:error, inspect(error)}
    end
  end

  @doc """
  Mutation: verifyOtp(code: String!)
  Verifies OTP using only the 6-digit code from email.
  Finds the most recent unused OTP that matches the code.
  """
  def verify_otp(_parent, %{code: code}, _resolution) do
    import Ecto.Query

    try do
      # Find all unused, non-expired OTPs
      query =
        from o in Otp,
          where: o.used == false and o.expires_at > ^DateTime.utc_now(),
          order_by: [desc: o.inserted_at],
          preload: :user

      # Get all matching OTPs and verify code against each
      otps = Repo.all(query)

      matching_otp =
        Enum.find(otps, fn otp ->
          Argon2.verify_pass(code, otp.code_hash)
        end)

      case matching_otp do
        nil ->
          {:error, "Invalid or expired OTP code"}

        otp ->
          with {:ok, tokens} <- Auth.generate_tokens(otp.user) do
            # Mark OTP as used
            otp
            |> Ecto.Changeset.change(used: true)
            |> Repo.update()

            # Update user status to ACTIVE and set email_verified_at if this is email verification
            updated_user =
              if otp.purpose == :email_verification do
                otp.user
                |> Ecto.Changeset.change(
                  status: :active,
                  email_verified_at: DateTime.utc_now()
                )
                |> Repo.update!()
              else
                otp.user
              end

            # Log the action
            MyAuthSystem.Audit.Log.log_async(
              otp.user_id,
              "LOGIN_SUCCESS",
              %{method: "otp", purpose: otp.purpose},
              nil
            )

            # Preload profile for response
            updated_user = Repo.preload(updated_user, :profile)

            {:ok,
             %{
               user: updated_user,
               token: tokens.access_token,
               refresh_token: tokens.refresh_token
             }}
          else
            {:error, reason} -> {:error, "Failed to generate tokens: #{inspect(reason)}"}
          end
      end
    rescue
      e -> {:error, "Error verifying OTP: #{inspect(e)}"}
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
      {:ok, result} ->
        # Preload profile for response
        user = Repo.preload(result.user, :profile)

        {:ok,
         %{
           user: user,
           token: result.access_token,
           refresh_token: result.refresh_token,
           message: "Token refreshed"
         }}

      {:error, message} ->
        {:error, message}
    end
  end

  # === PRIVATE HELPERS ===

  defp generate_otp_code do
    :crypto.strong_rand_bytes(6)
    |> :binary.bin_to_list()
    |> Enum.map(&rem(&1, 10))
    |> Enum.join()
  end


  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message -> "#{field} #{message}" end)
    end)
  end
end
