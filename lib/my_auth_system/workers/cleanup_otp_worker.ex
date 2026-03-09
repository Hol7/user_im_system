defmodule MyAuthSystem.Workers.CleanupOtpWorker do
  @moduledoc """
  Worker to clean up expired OTP codes periodically.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 1

  import Ecto.Query
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Auth.Otp

  @impl true
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    {deleted_count, _} =
      Repo.delete_all(
        from o in Otp,
          where: o.expires_at < ^now or o.used == true
      )

    {:ok, %{deleted: deleted_count}}
  end
end
