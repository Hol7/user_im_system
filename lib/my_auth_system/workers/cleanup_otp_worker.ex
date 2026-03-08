defmodule MyAuthSystem.Workers.CleanupOtpWorker do
  use Oban.Worker, queue: :default, max_attempts: 1

  @impl true
  def perform(%Oban.Job{args: %{"older_than_hours" => hours}}) do
    cutoff = DateTime.add(DateTime.utc_now(), -hours, :hour)

    MyAuthSystem.Repo.delete_all(
      from o in MyAuthSystem.Auth.Otp,
        where: o.expires_at < ^cutoff or o.used == true
    )
  end
end
