@doc """
Crée un utilisateur + profile + envoie email de bienvenue/validation.
"""
def create_user_with_validation(attrs) do
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, attrs))
  |> Ecto.Multi.run(:profile, fn repo, %{user: user} ->
    create_profile_changeset(user, attrs)
    |> repo.insert()
  end)
  |> Ecto.Multi.run(:validation_token, fn _repo, %{user: user} ->
    generate_email_validation_token(user)
  end)
  |> Ecto.Multi.run(:welcome_email, fn _repo, %{user: user, validation_token: token} ->
    send_welcome_email_async(user, token)
  end)
  |> MyAuthSystem.Repo.transaction()
  |> case do
    {:ok, %{user: user}} -> {:ok, user}
    {:error, :user, changeset, _} -> {:error, changeset}
    {:error, :profile, changeset, _} -> {:error, changeset}
    {:error, step, reason, _} -> {:error, %{step: step, reason: reason}}
  end
end

@doc """
Valide l'email d'un utilisateur via token.
"""
def validate_email(token) do
  case verify_validation_token(token) do
    {:ok, user} ->
      user
      |> Ecto.Changeset.change(status: :active, email_verified_at: DateTime.utc_now())
      |> MyAuthSystem.Repo.update()

    error ->
      error
  end
end

defp generate_email_validation_token(user) do
  # Token JWT court (24h) pour validation email
  MyAuthSystem.Auth.GuardianToken.encode_and_sign(user, %{},
    token_type: :email_validation,
    ttl: {24, :hours}
  )
end

defp verify_validation_token(token) do
  MyAuthSystem.Auth.GuardianToken.decode_and_verify(token, token_type: :email_validation)
  |> case do
    {:ok, %{"user_id" => user_id}} ->
      MyAuthSystem.Repo.get(User, user_id)
      |> case do
        nil -> {:error, :invalid_token}
        user -> {:ok, user}
      end

    _ ->
      {:error, :invalid_token}
  end
end

#
def create_admin_user(attrs) do
  %User{}
  |> User.registration_changeset(Map.put(attrs, :role, "admin"))
  |> Ecto.Changeset.put_change(:status, :active)
  |> Ecto.Changeset.put_change(:email_verified_at, DateTime.utc_now())
  |> Repo.insert()
end

defp send_welcome_email_async(user, token) do
  MyAuthSystem.Workers.EmailWorker.new(%{
    type: "welcome",
    email: user.email,
    name: user.profile.first_name,
    validation_token: token
  })
  |> Oban.insert()
end
