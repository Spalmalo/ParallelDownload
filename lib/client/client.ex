defmodule ParallelDownload.HTTPClient do
  @moduledoc """
  API on :httpc
  """
  use GenServer, restart: :transient
  require Logger

  alias ParallelDownload.DownloadTask
  alias ParallelDownload.HeadTask

  alias ParallelDownload.FileUtils
  alias ParallelDownload.TaskUtils

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init({parent_pid}) do
    {:ok, %{parent_pid: parent_pid}}
  end

  @doc """
  Starts file download process by given url.
  Second parameter is download chunk size in bytes.
  Stream is a stream to send data.
  """
  @spec run_request(binary(), pos_integer(), binary(), pid()) :: any()
  def run_request(url, chunk_size_bytes, path_to_save, parent_pid) do
    Logger.info("Start to download file from url: #{url},
    chunk size: #{chunk_size_bytes},
    path to save: #{path_to_save}")

    task_timeout = Application.get_env(:parallel_download, :task_await_timeout)

    start_head_request(url, task_timeout)
    |> case do
      {true, true, content_length} ->
        FileUtils.create_tmp_dir!()

        start_parallel_downloads(url, content_length, chunk_size_bytes, task_timeout)
        |> TaskUtils.extract_chunk_files()
        |> FileUtils.merge_files!(path_to_save)

        Logger.info("Successfully merged chunk files in to: #{path_to_save}")

        send(parent_pid, {:ok, path_to_save})
        time_to_die()

      {false, _, _} ->
        send(parent_pid, {:error, :server_error})
        time_to_die()

      {_, false, _} ->
        send(parent_pid, {:error, :not_supported})
        time_to_die()
    end
  end

  @doc """
  Starts async HEAD request by given url.
  Request to check if we can download file by given url.
  Returns tuple.
  """
  @spec start_head_request(binary(), any()) :: {boolean(), boolean(), pos_integer()}
  def start_head_request(url, task_timeout) do
    Task.async(fn -> HeadTask.head_request(url) end)
    |> Task.await(task_timeout)
  end

  @doc """
  Starts async requests to parallel download by given url.
  It creates async Tasks for each request. Number of requests depends on content length and chunk size.
  """
  @spec start_parallel_downloads(binary(), pos_integer(), pos_integer(), any()) :: list()
  def start_parallel_downloads(url, content_length, chunk_size, task_timeout) do
    TaskUtils.tasks_with_order(content_length, chunk_size)
    |> Enum.map(fn {header, index} ->
      chunk_tmp_file = FileUtils.create_tmp_file!()
      Task.async(fn -> DownloadTask.chunk_request(url, [header], chunk_tmp_file, index) end)
    end)
    |> Enum.map(&Task.await(&1, task_timeout))
  end

  @impl true
  def handle_info(:kill, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:download, url, chunk_size_bytes, path_to_save}, %{parent_pid: pid} = state) do
    run_request(url, chunk_size_bytes, path_to_save, pid)
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "HTTPClient is terminating with reason: #{inspect(reason)}, state: #{inspect(state)}"
    )

    state
  end

  defp time_to_die do
    send(self(), :kill)
  end
end
