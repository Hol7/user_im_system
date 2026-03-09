defmodule MyAuthSystem.Workers.CleanupRequestLogsWorker do
  @moduledoc """
  Oban worker to cleanup old request logs (older than 90 days).
  Runs daily at 3 AM via Cron plugin.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query
  alias MyAuthSystem.Repo
  alias MyAuthSystem.Monitoring.RequestLog

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"older_than_days" => days}}) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    {count, _} =
      from(l in RequestLog, where: l.inserted_at < ^cutoff_date)
      |> Repo.delete_all()

    {:ok, %{deleted: count}}
  end

  def perform(_job) do
    # Default: 90 days
    perform(%Oban.Job{args: %{"older_than_days" => 90}})
  end
end
