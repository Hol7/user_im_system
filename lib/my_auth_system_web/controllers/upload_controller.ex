defmodule MyAuthSystemWeb.UploadController do
  @moduledoc """
  Controller for handling file uploads (avatar, etc.).
  Uses local storage in priv/static/uploads.
  """

  use MyAuthSystemWeb, :controller

  @max_file_size 2 * 1024 * 1024
  @allowed_types ["image/jpeg", "image/png", "image/webp"]
  @upload_path Path.join([:code.priv_dir(:my_auth_system), "static", "uploads"])

  # CORRECT: Apply plugs to ALL actions, check inside function
  plug Guardian.Plug.VerifyHeader, realm: "Bearer"
  plug Guardian.Plug.LoadResource

  @doc """
  Handles avatar upload via multipart/form-data.
  """
  def upload_avatar(conn, %{"avatar" => upload}) do
    # Check authentication inside the function
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Authentication required"})

      user ->
        handle_upload(conn, upload, user)
    end
  end

  # Fallback for missing avatar param
  def upload_avatar(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: "Missing 'avatar' file in request"})
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  defp handle_upload(conn, upload, user) do
    with :ok <- validate_file_size(upload),
         :ok <- validate_file_type(upload),
         {:ok, filename} <- save_file(upload),
         {:ok, profile} <- update_user_avatar(user, filename) do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        data: %{
          avatar_url: "/uploads/#{filename}",
          profile: profile
        }
      })
    else
      {:error, :file_too_large} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "File too large (max 2MB)"})

      {:error, :invalid_type} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Invalid file type. Allowed: jpg, png, webp"})

      {:error, :save_failed} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Failed to save file"})

      {:error, :profile_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "User profile not found"})

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Validation failed",
          details: Ecto.Changeset.traverse_errors(changeset, & &1)
        })

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "An unexpected error occurred"})
    end
  end

  defp validate_file_size(upload) do
    if upload.size <= @max_file_size do
      :ok
    else
      {:error, :file_too_large}
    end
  end

  defp validate_file_type(upload) do
    if upload.content_type in @allowed_types do
      :ok
    else
      {:error, :invalid_type}
    end
  end

  defp save_file(upload) do
    filename = "#{Ecto.UUID.generate()}_#{Path.basename(upload.filename)}"
    filepath = Path.join(@upload_path, filename)

    File.mkdir_p!(@upload_path)

    case File.write(filepath, upload.content) do
      :ok -> {:ok, filename}
      _ -> {:error, :save_failed}
    end
  end

  defp update_user_avatar(user, filename) do
    relative_path = "uploads/#{filename}"

    user
    |> MyAuthSystem.Repo.preload(:profile)
    |> case do
      %MyAuthSystem.Accounts.User{profile: nil} ->
        {:error, :profile_not_found}

      %MyAuthSystem.Accounts.User{profile: profile} ->
        profile
        |> MyAuthSystem.Accounts.Profile.changeset(%{avatar_path: relative_path})
        |> MyAuthSystem.Repo.update()
    end
  end
end
