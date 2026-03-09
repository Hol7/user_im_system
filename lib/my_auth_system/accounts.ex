defmodule MyAuthSystem.Accounts do
  @moduledoc """
  The Accounts context. This is the PUBLIC API for managing users and profiles.
  """

  import Ecto.Query
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Accounts.{User, Profile}
  alias MyAuthSystem.Auth.GuardianToken
  alias MyAuthSystem.Workers.EmailWorker

  # =============================================================================
  # USER CREATION & REGISTRATION (With Email Validation)
  # =============================================================================

  @doc """
  Creates a new user with profile and sends validation email.
  Used during public registration.
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
    |> Ecto.Multi.run(:welcome_email, fn _repo, %{user: user, validation_token: {:ok, token}} ->
      send_welcome_email_async(user, token)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, :profile, changeset, _} -> {:error, changeset}
      {:error, step, reason, _} -> {:error, %{step: step, reason: reason}}
    end
  end

  @doc """
  Simple user creation (without validation email).
  Used by admins or internal processes.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an admin user directly (bypasses email validation).
  """
  def create_admin_user(attrs) do
    %User{}
    |> User.registration_changeset(Map.put(attrs, :role, "admin"))
    |> Ecto.Changeset.put_change(:status, :active)
    |> Ecto.Changeset.put_change(:email_verified_at, DateTime.utc_now())
    |> Repo.insert()
  end

  @doc """
  Creates a profile for an existing user.
  """
  def create_profile(%User{} = user, attrs \\ %{}) do
    %Profile{user_id: user.id}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  # =============================================================================
  # EMAIL VALIDATION (Token-based)
  # =============================================================================

  @doc """
  Validates user email using token from email link.
  """
  def validate_email(token) do
    case verify_validation_token(token) do
      {:ok, user} ->
        user
        |> Ecto.Changeset.change(status: :active, email_verified_at: DateTime.utc_now())
        |> Repo.update()

      error ->
        error
    end
  end

  # =============================================================================
  # USER RETRIEVAL
  # =============================================================================

  @doc """
  Gets a single user by ID.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a single user by email.
  """
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc """
  Gets a user by ID and preloads their profile.
  """
  def get_user_with_profile(id) do
    Repo.get(User, id) |> Repo.preload(:profile)
  end

  # =============================================================================
  # PROFILE MANAGEMENT
  # =============================================================================

  @doc """
  Updates a user's profile.
  """
  def update_profile(%User{} = user, attrs) do
    user
    |> Repo.preload(:profile)
    |> case do
      %User{profile: nil} ->
        create_profile(user, attrs)

      %User{profile: profile} ->
        profile
        |> Profile.changeset(attrs)
        |> Repo.update()
    end
  end

  # =============================================================================
  # ADMIN FUNCTIONS
  # =============================================================================

  @doc """
  Admin updates a user (including role, status, etc.).
  """
  def admin_update_user(%User{} = user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft deletes a user (marks for deletion).
  """
  def hard_delete_user(user_id) do
    # Evaluate DateTime BEFORE the query
    now = DateTime.utc_now()

    # Anonymize User
    from(u in User,
      where: u.id == ^user_id,
      update: [
        set: [
          email: fragment("CONCAT('deleted_', id, '@deleted.local')"),
          password_hash: nil,
          status: :deleted,
          deleted_at: ^now,
          role: :user
        ]
      ]
    )
    |> Repo.update_all([])

    # Anonymize Profile
    from(p in Profile,
      where: p.user_id == ^user_id,
      update: [
        set: [
          first_name: "Deleted",
          last_name: "User",
          phone: nil,
          country: nil,
          city: nil,
          district: nil,
          avatar_path: nil
        ]
      ]
    )
    |> Repo.update_all([])
  end

  def soft_delete_user(user_id) do
    # Evaluate DateTime BEFORE the query
    now = DateTime.utc_now()

    from(u in User,
      where: u.id == ^user_id,
      update: [
        set: [
          status: :deletion_requested,
          deleted_at: ^now
        ]
      ]
    )
    |> Repo.update_all([])
  end

  @doc """
  Validates a user account (Admin approves pending user).
  """
  def validate_user_account(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        user
        |> Ecto.Changeset.change(
          status: :active,
          email_verified_at: DateTime.utc_now()
        )
        |> Repo.update()
    end
  end

  @doc """
  Requests account deletion for a user.
  """
  def request_account_deletion(user) do
    user
    |> Ecto.Changeset.change(
      status: :deletion_requested,
      deleted_at: DateTime.utc_now()
    )
    |> Repo.update()
  end

  @doc """
  Restores a user (Rejects deletion request).
  """
  def restore_user(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        user
        |> Ecto.Changeset.change(
          status: :active,
          deleted_at: nil
        )
        |> Repo.update()
    end
  end

  @doc """
  Lists users with filtering (for Admin Dashboard).
  """
  def list_users(filters \\ %{}) do
    User
    |> apply_filters(filters)
    |> preload(:profile)
    |> Repo.all()
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  defp create_profile_changeset(user, attrs) do
    %Profile{user_id: user.id}
    |> Profile.changeset(attrs)
  end

  defp generate_email_validation_token(user) do
    GuardianToken.encode_and_sign(user, %{},
      token_type: :email_validation,
      ttl: {24, :hours}
    )
  end

  defp verify_validation_token(token) do
    GuardianToken.decode_and_verify(token, token_type: :email_validation)
    |> case do
      {:ok, %{"user_id" => user_id}} ->
        Repo.get(User, user_id)
        |> case do
          nil -> {:error, :invalid_token}
          user -> {:ok, user}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  defp send_welcome_email_async(user, token) do
    EmailWorker.new(%{
      type: "welcome",
      email: user.email,
      name: user.profile.first_name || "User",
      validation_token: token
    })
    |> Oban.insert()
  end

  defp apply_filters(query, %{"status" => status}) when status != nil and status != "" do
    query |> where([u], u.status == ^status)
  end

  defp apply_filters(query, %{"search" => term}) when term != nil and term != "" do
    search_term = "%#{String.downcase(term)}%"
    query |> where([u], fragment("LOWER(?) LIKE ?", u.email, ^search_term))
  end

  defp apply_filters(query, _filters), do: query
end
