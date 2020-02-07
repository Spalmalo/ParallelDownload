defmodule ParallelDownload.HTTPClient do
  @moduledoc """
  API on :httpc
  """
  use GenServer, restart: :transient
  require Logger

  alias ParallelDownload.DownloadTask
  alias ParallelDownload.HeadTask
  alias ParallelDownload.HTTPUtils
  alias ParallelDownload.FileUtils
  alias ParallelDownload.TaskUtils

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init({parent_pid}) do
    {:ok, %{parent_pid: parent_pid}}
  end

  @spec run_request(binary(), pos_integer(), binary() | Path.t(), pid, keyword()) :: any()
  def run_request(url, chunk_size_bytes, path_to_save, parent_pid, timeout_opts) do
    Logger.info(
      "Start to download file from url: #{url}, chunk size: #{chunk_size_bytes}, path to save: #{
        path_to_save
      }"
    )

    task_timeout = Application.get_env(:parallel_download, :task_await_timeout)

    start_head_request(url, task_timeout, timeout_opts)
    |> case do
      {true, true, content_length} ->
        FileUtils.create_tmp_dir!()

        start_parallel_downloads(
          url,
          content_length,
          chunk_size_bytes,
          task_timeout,
          timeout_opts
        )
        |> TaskUtils.extract_chunk_files()
        |> FileUtils.merge_files!(path_to_save)

        Logger.info("Successfully merged chunk files in to: #{path_to_save}")

        send(parent_pid, {:ok, path_to_save})
        to_kurt_kobain()

      {false, _, _} ->
        send(parent_pid, {:error, :server_error})
        to_kurt_kobain()

      {_, false, _} ->
        send(parent_pid, {:error, :not_supported})
        to_kurt_kobain()

      {:error, reason} ->
        send(parent_pid, {:error, :server_error, reason})
        to_kurt_kobain()
    end
  end

  @doc """
  Starts async HEAD request by given url.
  Request to check if we can download file by given url.
  Returns tuple.
  """
  @spec start_head_request(binary(), timeout(), keyword()) :: any()
  def start_head_request(url, task_timeout, timeout_opts) do
    request = HTTPUtils.request_for_url(url)
    http_options = HTTPUtils.http_options(timeout_opts)

    Task.async(fn -> HeadTask.head_request(request, http_options) end)
    |> Task.await(task_timeout)
  end

  @doc """
  Starts async requests to parallel download by given url.
  It creates async Tasks for each request. Number of requests depends on content length and chunk size.
  """
  @spec start_parallel_downloads(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          timeout(),
          keyword()
        ) :: any()
  def start_parallel_downloads(url, content_length, chunk_size, task_timeout, timeout_opts) do
    http_options = HTTPUtils.http_options(timeout_opts)

    TaskUtils.tasks_with_order(content_length, chunk_size)
    |> Enum.map(fn {header, index} ->
      options =
        FileUtils.create_tmp_file!()
        |> HTTPUtils.options()

      request = HTTPUtils.request_for_url(url, header)

      Task.async(fn -> DownloadTask.chunk_request(request, http_options, options, index) end)
    end)
    |> Enum.map(&Task.await(&1, task_timeout))
  end

  @impl true
  def handle_info(:kill, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast(
        {:download, url, chunk_size_bytes, path_to_save, opts},
        %{parent_pid: pid} = state
      ) do
    run_request(url, chunk_size_bytes, path_to_save, pid, opts)
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "HTTPClient is terminating with reason: #{inspect(reason)}, state: #{inspect(state)}"
    )

    state
  end

  defp to_kurt_kobain do
    send(self(), :kill)
  end
end

