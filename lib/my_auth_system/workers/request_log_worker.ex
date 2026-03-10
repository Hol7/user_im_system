defmodule MyAuthSystem.Workers.RequestLogWorker do
  @moduledoc """
  Oban worker to log GraphQL requests asynchronously.
  This prevents telemetry handlers from blocking on database inserts.
  """
  use Oban.Worker, queue: :audits, max_attempts: 2

  alias MyAuthSystem.Monitoring.RequestLog
  alias MyAuthSystem.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %RequestLog{}
    |> RequestLog.changeset(args)
    |> Repo.insert()
    |> case do
      {:ok, _log} -> :ok
      {:error, _changeset} -> :ok # Don't retry on validation errors
    end
  end
end
