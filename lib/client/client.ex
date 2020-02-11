defmodule ParallelDownload.HTTPClient do
  @moduledoc """
  API on :httpc
  """
  use GenServer, restart: :transient
  require Logger

  alias ParallelDownload.HTTPUtils
  alias ParallelDownload.FileUtils
  alias ParallelDownload.TaskUtils
  alias ParallelDownload.TaskSupervisor

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init({parent_pid, url, chunk_size_bytes, path_to_save, timeout_opts}) do
    :inets.start()
    :ssl.start()
    {:ok, supervisor_pid} = TaskSupervisor.start_link()
    {:ok, _} = start_head_request(url, timeout_opts)

    {:ok,
     %{
       parent_pid: parent_pid,
       url: url,
       chunk_size: chunk_size_bytes,
       path_to_save: path_to_save,
       timeout_opts: timeout_opts,
       supervisor_pid: supervisor_pid,
       chunks: [],
       chunks_count: 0
     }}
  end

  @doc """
  Starts async HEAD request by given url.
  Request to check if we can download file by given url.
  Returns tuple.
  """
  @spec start_head_request(binary(), keyword()) :: any()
  def start_head_request(url, timeout_opts) do
    request = HTTPUtils.request_for_url(url)
    http_options = HTTPUtils.http_options(timeout_opts)
    TaskSupervisor.start_head_task([request, http_options, self()])
  end

  def handle_head_response({:error, reason}, %{parent_pid: parent_pid} = state) do
    send(parent_pid, {:error, :server_error, reason})
    to_kurt_kobain()
    state
  end

  def handle_head_response({false, _, _}, %{parent_pid: parent_pid} = state) do
    send(parent_pid, {:error, :server_error})
    to_kurt_kobain()
    state
  end

  def handle_head_response({_, false, _}, %{parent_pid: parent_pid} = state) do
    send(parent_pid, {:error, :not_supported})
    to_kurt_kobain()
    state
  end

  def handle_head_response(
        {true, true, content_length},
        %{url: url, chunk_size: chunk_size_bytes, timeout_opts: timeout_opts} = state
      ) do
    FileUtils.create_tmp_dir!()
    tasks = start_parallel_downloads(url, content_length, chunk_size_bytes, timeout_opts)
    Map.put(state, :chunks_count, length(tasks))
  end

  @doc """
  Starts async requests to parallel download by given url.
  It creates async Tasks for each request. Number of requests depends on content length and chunk size.
  """
  @spec start_parallel_downloads(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          keyword()
        ) :: list()
  def start_parallel_downloads(url, content_length, chunk_size, timeout_opts) do
    http_options = HTTPUtils.http_options(timeout_opts)

    TaskUtils.tasks_with_order(content_length, chunk_size)
    |> Enum.map(fn {header, index} ->
      options =
        FileUtils.create_tmp_file!()
        |> HTTPUtils.options()

      request = HTTPUtils.request_for_url(url, header)
      TaskSupervisor.start_download_task([request, http_options, options, index, self()])
    end)
  end

  def handle_chunk_response({:ok, path_to_file, index}, %{chunks: chunks} = state) do
    state
    |> Map.put(:chunks, chunks ++ [{path_to_file, index}])
  end

  @impl true
  def handle_call({:head_request, response}, _from, state) do
    new_state = handle_head_response(response, state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:chunk_request, response}, _from, state) do
    new_state = handle_chunk_response(response, state)

    case new_state do
      %{
        chunks_count: chunks_count,
        chunks: chunks,
        path_to_save: path_to_save,
        parent_pid: parent_pid
      }
      when length(chunks) == chunks_count ->
        TaskUtils.extract_chunk_files(chunks)
        |> FileUtils.merge_files!(path_to_save)

        Logger.info("Successfully merged chunk files in to: #{path_to_save}")

        send(parent_pid, {:ok, path_to_save})
        to_kurt_kobain()
        {:reply, :ok, new_state}

      _ ->
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_info(:kill, state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(reason, %{supervisor_pid: supervisor_pid} = state) do
    Logger.info(
      "HTTPClient is terminating with reason: #{inspect(reason)}, state: #{inspect(state)}"
    )

    :inets.stop()
    :ssl.stop()
    TaskSupervisor.stop(supervisor_pid)
    state
  end

  defp to_kurt_kobain do
    send(self(), :kill)
  end
end
