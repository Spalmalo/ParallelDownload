defmodule ParallelDownload.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        ParallelDownload.Supervisor
      ],
      strategy: :one_for_one
    )
  end
end
