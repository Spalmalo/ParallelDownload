defmodule ParallelDownload.TaskSupervisor do
  @moduledoc """
  Dynamic supervisor for download tasks: ParallelDownload.HeadTask and ParallelDownload.DownloadTask.
  Since it starts dynamically for each ParallelDownload.HTTPClient, it doesn't use name registration.
  """
  use DynamicSupervisor

  @doc """
  Starts TaskSupervisor and passes given arguments.
  Returns Supervisor.on_start()
  """
  @spec start_link(any) :: Supervisor.on_start()
  def start_link(arg \\ %{}) do
    DynamicSupervisor.start_link(__MODULE__, arg)
  end

  @doc """
  Starts ParallelDownload.HeadTask under supervisor and passes given arguments.
  Returns Supervisor.on_start_child()
  """
  @spec start_head_task(pid(), any()) :: Supervisor.on_start_child()
  def start_head_task(supervisor_pid, args) do
    spec = {ParallelDownload.HeadTask, args}
    DynamicSupervisor.start_child(supervisor_pid, spec)
  end

  @doc """
  Starts ParallelDownload.DownloadTask under supervisor and passes given arguments.
  Returns Supervisor.on_start_child()
  """
  @spec start_download_task(pid(), any()) :: Supervisor.on_start_child()
  def start_download_task(supervisor_pid, args) do
    spec = {ParallelDownload.DownloadTask, args}
    DynamicSupervisor.start_child(supervisor_pid, spec)
  end

  @doc """
  Stops supervisor with given pid.
  """
  @spec stop(pid) :: :ok
  def stop(pid) do
    DynamicSupervisor.stop(pid)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
