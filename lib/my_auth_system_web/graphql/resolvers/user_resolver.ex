defmodule MyAuthSystemWeb.GraphQL.Resolvers.UserResolver do
  alias MyAuthSystem.Accounts
  alias MyAuthSystem.Auth

  def logout(_parent, %{refresh_token: refresh_token}, %{context: %{current_user: user}}) when not is_nil(user) do
    case Auth.logout(user.id, refresh_token) do
      {:ok, message} -> {:ok, %{message: message}}
      {:error, reason} -> {:error, reason}
    end
  end

  def logout(_parent, _args, _resolution) do
    {:error, "Unauthorized"}
  end

  def get_me(_parent, _args, %{context: %{current_user: user}}) when not is_nil(user) do
    {:ok, user}
  end

  def get_me(_parent, _args, _resolution) do
    {:error, "Unauthorized"}
  end

  def update_profile(_parent, %{input: input}, %{context: %{current_user: user}})
      when not is_nil(user) do
    case Accounts.update_profile(user, input) do
      {:ok, profile} -> {:ok, %{profile: profile, message: "Profile updated"}}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} when is_atom(reason) -> {:error, Atom.to_string(reason)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  def update_profile(_parent, _args, _resolution) do
    {:error, "Unauthorized"}
  end

  def request_deletion(_parent, _args, %{context: %{current_user: user}}) when not is_nil(user) do
    case Accounts.request_account_deletion(user) do
      {:ok, _user} -> {:ok, %{message: "Account deletion requested. You have 30 days to cancel."}}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_errors(changeset)}
      {:error, reason} when is_atom(reason) -> {:error, Atom.to_string(reason)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  def request_deletion(_parent, _args, _resolution) do
    {:error, "Unauthorized"}
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
