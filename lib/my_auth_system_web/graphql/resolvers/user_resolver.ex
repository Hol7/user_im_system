defmodule MyAuthSystemWeb.GraphQL.Resolvers.UserResolver do
  alias MyAuthSystem.Accounts

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
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def update_profile(_parent, _args, _resolution) do
    {:error, "Unauthorized"}
  end

  def request_deletion(_parent, _args, %{context: %{current_user: user}}) when not is_nil(user) do
    case Accounts.request_account_deletion(user) do
      {:ok, _user} -> {:ok, %{message: "Account deletion requested. You have 30 days to cancel."}}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def request_deletion(_parent, _args, _resolution) do
    {:error, "Unauthorized"}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
