defmodule MyAuthSystemWeb.UploadController do
  use MyAuthSystemWeb, :controller

  @max_file_size 2 * 1024 * 1024 # 2MB
  @allowed_types ["image/jpeg", "image/png", "image/webp"]
  @upload_path Path.join([:code.priv_dir(:my_auth_system), "static", "uploads"])

  plug Guardian.Plug.VerifyHeader, realm: "Bearer" when action in [:upload_avatar]
  plug Guardian.Plug.LoadResource when action in [:upload_avatar]

  def upload_avatar(conn, %{"avatar" => upload}) do
    with :ok <- validate_file_size(upload),
         :ok <- validate_file_type(upload),
         {:ok, file_path} <- save_file(upload),
         {:ok, user} <- Guardian.Plug.current_resource(conn),
         {:ok, profile} <- update_user_avatar(user, file_path) do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
         %{
          avatar_url: "/uploads/#{Path.basename(file_path)}",
          profile: profile
        }
      })
    else
      {:error, :file_too_large} ->
        conn |> put_status(:bad_request) |> json(%{error: "File too large (max 2MB)"})
      {:error, :invalid_type} ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid file type. Allowed: jpg, png, webp"})
      {:error, :save_failed} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Failed to save file"})
      {:error, :unauthorized} ->
        conn |> put_status(:unauthorized) |> json(%{error: "Authentication required"})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: Ecto.Changeset.traverse_errors(changeset, &(&1))})
    end
  end

  defp validate_file_size(upload) do
    if upload.size <= @max_file_size, do: :ok, else: {:error, :file_too_large}
  end

  defp validate_file_type(upload) do
    if upload.content_type in @allowed_types, do: :ok, else: {:error, :invalid_type}
  end

  defp save_file(upload) do
    # Générer un nom de fichier unique
    filename = "#{Ecto.UUID.generate()}_#{Path.basename(upload.filename)}"
    filepath = Path.join(@upload_path, filename)

    # S'assurer que le dossier existe
    File.mkdir_p!(@upload_path)

    case File.write(filepath, upload.content) do
      :ok -> {:ok, filepath}
      _ -> {:error, :save_failed}
    end
  end

  defp update_user_avatar(user, file_path) do
    relative_path = Path.join("uploads", Path.basename(file_path))

    user
    |> Ecto.assoc(:profile)
    |> MyAuthSystem.Repo.one()
    |> case do
      nil -> {:error, :profile_not_found}
      profile ->
        profile
        |> MyAuthSystem.Accounts.Profile.changeset(%{avatar_path: relative_path})
        |> MyAuthSystem.Repo.update()
    end
  end
end
