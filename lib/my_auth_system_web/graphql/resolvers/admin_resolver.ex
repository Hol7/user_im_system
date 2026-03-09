# lib/my_auth_system_web/graphql/resolvers/admin_resolver.ex
defmodule MyAuthSystemWeb.GraphQL.Resolvers.AdminResolver do
  alias MyAuthSystem.Accounts
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Accounts.User
  import Ecto.Query


  @doc """
  Mutation: adminCreateUser(input: AdminUserInput!)
  Seul un super_admin peut créer un autre admin.
  """
  def create_user(_parent, %{input: input}, %{context: %{current_user: current_user}}) do
    with true <- current_user.role in [:admin, :super_admin] || {:error, :forbidden},
         {:ok, user} <- Accounts.create_admin_user(input) do
      {:ok, %{user: user}}
    else
      {:error, :forbidden} -> {:error, "Only admins can create admin accounts"}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def create_user(_parent, _args, _resolution), do: {:error, "Unauthorized"}




  # LIST USERS (with Relay pagination)
  def list_users(_parent, args, %{context: %{current_user: user}}) do
    with true <- user.role in [:admin, :super_admin] || {:error, :forbidden} do
      query =
        User
        |> preload(:profile)
        |> maybe_filter_by_status(args[:status])
        |> maybe_filter_by_role(args[:role])
        |> maybe_search(args[:search])
        |> maybe_sort(args[:sort_by], args[:sort_order])

      {:ok, Absinthe.Relay.Connection.from_query(query, &Repo.all/1, args)}
    end
  end

  # GET USER BY ID
  def get_user(_parent, %{id: id}, %{context: %{current_user: user}}) do
    with true <- user.role in [:admin, :super_admin] || {:error, :forbidden},
         user_found <- Repo.get(User, id) |> Repo.preload(:profile) do
      {:ok, user_found}
    else
      {:error, :forbidden} -> {:error, "Forbidden"}
      nil -> {:error, "User not found"}
    end
  end

  # UPDATE USER
  def update_user(_parent, %{id: id, input: input}, %{context: %{current_user: admin}}) do
    with true <- admin.role in [:admin, :super_admin] || {:error, :forbidden},
         user <- Repo.get(User, id),
         {:ok, user} <- MyAuthSystem.Accounts.admin_update_user(user, input) do
      {:ok, %{user: user, message: "User updated successfully"}}
    else
      {:error, :forbidden} -> {:error, "Forbidden"}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  # DELETE USER (soft delete)
  def delete_user(_parent, %{id: id}, %{context: %{current_user: admin}}) do
    with true <- admin.role in [:admin, :super_admin] || {:error, :forbidden},
         {:ok, _} <- MyAuthSystem.Accounts.soft_delete_user(id) do
      {:ok, %{message: "User marked for deletion"}}
    else
      {:error, :forbidden} -> {:error, "Forbidden"}
      error -> error
    end
  end

  # VALIDATE USER (approve pending account)
  def validate_user(_parent, %{id: id}, %{context: %{current_user: admin}}) do
    with true <- admin.role in [:admin, :super_admin] || {:error, :forbidden},
         {:ok, user} <- MyAuthSystem.Accounts.validate_user_account(id) do
      {:ok, %{user: user, message: "Account validated"}}
    else
      {:error, :forbidden} -> {:error, "Forbidden"}
      error -> error
    end
  end

  # LIST DELETION REQUESTS
  def list_deletion_requests(_parent, _args, %{context: %{current_user: user}}) do
    with true <- user.role in [:admin, :super_admin] || {:error, :forbidden} do
      users =
        User
        |> where([u], u.status == ^:deletion_requested)
        |> preload(:profile)
        |> Repo.all()
      {:ok, users}
    end
  end

  # PROCESS DELETION REQUEST
  def process_deletion(_parent, %{id: id, action: :approve}, %{context: %{current_user: admin}}) do
    with true <- admin.role in [:admin, :super_admin] || {:error, :forbidden},
         :ok <- MyAuthSystem.Accounts.hard_delete_user(id) do
      {:ok, %{message: "User permanently deleted"}}
    end
  end

  def process_deletion(_parent, %{id: id, action: :reject}, %{context: %{current_user: admin}}) do
    with true <- admin.role in [:admin, :super_admin] || {:error, :forbidden},
         {:ok, _user} <- MyAuthSystem.Accounts.restore_user(id) do
      {:ok, %{message: "Deletion request rejected, account restored"}}
    end
  end

  # AUDIT LOGS
  def list_audit_logs(_parent, %{user_id: user_id, action: action, limit: limit}, %{context: %{current_user: admin}}) do
    with true <- admin.role in [:admin, :super_admin] || {:error, :forbidden} do
      logs =
        MyAuthSystem.Audit.Log
        |> maybe_filter_by_user(user_id)
        |> maybe_filter_by_action(action)
        |> order_by(desc: :inserted_at)
        |> limit(^limit)
        |> Repo.all()
      {:ok, logs}
    end
  end

  # Helpers
  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, [u], u.status == ^status)

  defp maybe_filter_by_role(query, nil), do: query
  defp maybe_filter_by_role(query, role), do: where(query, [u], u.role == ^role)

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, term) do
    search_term = "%#{String.downcase(term)}%"
    where(query, [u],
      ilike(u.email, ^search_term)
    )
  end

  defp maybe_sort(query, :inserted_at, :desc), do: order_by(query, [u], desc: u.inserted_at)
  defp maybe_sort(query, :inserted_at, :asc), do: order_by(query, [u], asc: u.inserted_at)
  defp maybe_sort(query, :last_login_at, :desc), do: order_by(query, [u], desc: u.last_login_at)
  defp maybe_sort(query, :email, :asc), do: order_by(query, [u], asc: u.email)
  # ... add more sort cases

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id), do: where(query, [l], l.user_id == ^user_id)

  defp maybe_filter_by_action(query, nil), do: query
  defp maybe_filter_by_action(query, action), do: where(query, [l], l.action == ^action)

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

end
