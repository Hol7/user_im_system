defmodule MyAuthSystem.Workers.AuditLogWorker do
  @moduledoc """
  Worker pour écrire les logs d'audit dans la DB.
  """
  use Oban.Worker, queue: :audits, max_attempts: 1

  @impl true
  def perform(%Oban.Job{args: args}) do
    %MyAuthSystem.Audit.Log{}
    |> MyAuthSystem.Audit.Log.changeset(args)
    |> MyAuthSystem.Repo.insert()
  end
end
