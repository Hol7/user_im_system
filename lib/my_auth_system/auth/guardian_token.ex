defmodule MyAuthSystem.Auth.GuardianToken do
  @moduledoc """
  Module personnalisé pour Guardian avec gestion des rôles et permissions.
  """
  use Guardian.Token.Jwt

  @impl true
  def build_claims(claims, resource, opts) do
    claims
    |> Map.put("user_id", resource.id)
    |> Map.put("role", resource.role)
    |> Map.put("email", resource.email)
    |> super(resource, opts)
  end

  @impl true
  def verify_claims(claims, _opts) do
    with {:ok, _} <- super(claims, %{}),
         true <- Map.has_key?(claims, "user_id"),
         true <- Map.has_key?(claims, "exp"),
         true <- claims["exp"] > System.system_time(:second) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_claims}
    end
  end
end
