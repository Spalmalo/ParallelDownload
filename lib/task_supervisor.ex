defmodule ParallelDownload.TaskSupervisor do
  use DynamicSupervisor

  def start_link(arg \\ %{}) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def start_head_task(args) do
    spec = {ParallelDownload.HeadTask, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_download_task(args) do
    spec = {ParallelDownload.DownloadTask, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop(pid) do
    DynamicSupervisor.stop(pid)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
