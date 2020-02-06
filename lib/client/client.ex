defmodule ParallelDownload.HTTPClient do
  @moduledoc """
  API on :httpc
  """
  alias ParallelDownload.DownloadTask
  alias ParallelDownload.HeadTask
  alias ParallelDownload.TaskSupervisor
  alias ParallelDownload.FileUtils
  alias ParallelDownload.TaskUtils

  @doc """
  Starts file download process by given url.
  Second parameter is download chunk size in bytes.
  Stream is a stream to send data.
  """
  @spec run_request(binary(), pos_integer(), binary()) :: {:ok, binary()} | {:error, term()}
  def run_request(url, chunk_size_bytes, path_to_save) do
    task_timeout = Application.get_env(:parallel_download, :task_await_timeout)

    start_head_request(url, task_timeout)
    |> case do
      {true, true, content_length} ->
        FileUtils.create_tmp_dir!()

        start_parallel_downloads(url, content_length, chunk_size_bytes, task_timeout)
        |> TaskUtils.extract_chunk_files()
        |> FileUtils.merge_files!(path_to_save)

        {:ok, path_to_save}

      {false, _, _} ->
        {:error, :server_error}

      {_, false, _} ->
        {:error, :not_supported}
    end
  end

  @doc """
  Starts async HEAD request by given url.
  Request to check if we can download file by given url.
  Returns tuple.
  """
  @spec start_head_request(binary(), any()) :: {boolean(), boolean(), pos_integer()}
  def start_head_request(url, task_timeout) do
    Task.Supervisor.async(TaskSupervisor, fn -> HeadTask.head_request(url) end)
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

      Task.Supervisor.async(
        TaskSupervisor,
        fn -> DownloadTask.chunk_request(url, [header], chunk_tmp_file, index) end
      )
    end)
    |> Enum.map(&Task.await(&1, task_timeout))
  end
end
