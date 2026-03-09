defmodule MyAuthSystem.Auth.GuardianToken do
  @moduledoc """
  Guardian module for JWT token management.
  """

  use Guardian, otp_app: :my_auth_system

  @doc """
  Called when a token is built. Add custom claims here.
  """
  def build_claims(claims, resource, opts) do
    claims
    |> Map.put("user_id", resource.id)
    |> Map.put("role", resource.role)
    |> Map.put("email", resource.email)
    |> super(resource, opts)
  end

  @doc """
  Called when a token is verified. Add custom validation here.
  """
  def verify_claims(claims, opts) do
    with {:ok, claims} <- super(claims, opts),
         true <- Map.has_key?(claims, "user_id") || {:error, :missing_user_id},
         true <- Map.has_key?(claims, "exp") || {:error, :missing_exp},
         true <- claims["exp"] > System.system_time(:second) || {:error, :expired} do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_claims}
    end
  end

  @doc """
  Get the subject from the resource.
  """
  def subject_for_token(resource, _claims) do
    sub = to_string(resource.id)
    {:ok, sub}
  end

  @doc """
  Get the resource from the subject.
  """
  def resource_from_claims(%{"user_id" => user_id}) do
    case MyAuthSystem.Repo.get(MyAuthSystem.Accounts.User, user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}
end

# defmodule MyAuthSystem.Auth.GuardianToken do
#   @moduledoc """
#   Module personnalisé pour Guardian avec gestion des rôles et permissions.
#   """
#   use Guardian.Token.Jwt

#   @impl true
#   def build_claims(claims, resource, opts) do
#     claims
#     |> Map.put("user_id", resource.id)
#     |> Map.put("role", resource.role)
#     |> Map.put("email", resource.email)
#     |> super(resource, opts)
#   end

#   @impl true
#   def verify_claims(claims, _opts) do
#     with {:ok, _} <- super(claims, %{}),
#          true <- Map.has_key?(claims, "user_id"),
#          true <- Map.has_key?(claims, "exp"),
#          true <- claims["exp"] > System.system_time(:second) do
#       {:ok, claims}
#     else
#       _ -> {:error, :invalid_claims}
#     end
#   end
# end
