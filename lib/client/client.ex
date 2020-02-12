defmodule ParallelDownload.HTTPClient do
  @moduledoc """
  Module starts downloading tasks, merges chunk files in to resulting one and returns it.
  Uses GenServer's transient strategy.
  Starts `ParallelDownload.TaskSupervisor` and `:inets` and `:ssl` on GenServer init/1 callback.
  Each task is started under `ParallelDownload.TaskSupervisor`.
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
    {:ok, _} = start_head_request(url, timeout_opts, supervisor_pid)

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
     }, :hibernate}
  end

  @doc """
  Starts async `HEAD` request by given url to find out if we can download file by given url.
  Returns tuple.
  """
  @spec start_head_request(binary(), keyword(), pid()) :: any()
  def start_head_request(url, timeout_opts, supervisor_pid) do
    request = HTTPUtils.request_for_url(url)
    http_options = HTTPUtils.http_options(timeout_opts)
    TaskSupervisor.start_head_task(supervisor_pid, [request, http_options, self()])
  end

  @doc """
  Handles response from `HEAD` request.
  if file can be downloaded in chunks starts downloading and hibernates.
  In error cases or if server doesn't supports chunk downloading sends error request to parent pid and starts killing itself.

  Returns `{:noreply, state, hibernate}` if response is correct and chunk downloading started.
  Returns `{:stop, :normal, state}` if there was an error or server doesn't support chunk downloading.
  """
  @spec handle_head_response({:error, any} | {any, any, any}, map) ::
          {:stop, :normal, map()} | {:noreply, map(), :hibernate}
  def handle_head_response({:error, reason}, %{parent_pid: parent_pid} = state) do
    send(parent_pid, {:error, :server_error, reason})
    {:stop, :normal, state}
  end

  def handle_head_response({false, _, _}, %{parent_pid: parent_pid} = state) do
    send(parent_pid, {:error, :server_error})
    {:stop, :normal, state}
  end

  def handle_head_response({_, false, _}, %{parent_pid: parent_pid} = state) do
    send(parent_pid, {:error, :not_supported})
    {:stop, :normal, state}
  end

  def handle_head_response(
        {true, true, content_length},
        %{
          url: url,
          chunk_size: chunk_size_bytes,
          timeout_opts: timeout_opts,
          supervisor_pid: supervisor_pid
        } = state
      ) do
    FileUtils.create_tmp_dir!()

    tasks =
      start_parallel_downloads(
        url,
        content_length,
        chunk_size_bytes,
        timeout_opts,
        supervisor_pid
      )

    new_state = Map.put(state, :chunks_count, length(tasks))
    {:noreply, new_state, :hibernate}
  end

  @doc """
  Starts async requests to parallel download chunks by given url.
  It creates async `Tasks` for each request. Number of requests depends on content length and chunk size.
  Creates temporary directory to keep chunk files.
  """
  @spec start_parallel_downloads(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          keyword(),
          pid()
        ) :: list()
  def start_parallel_downloads(url, content_length, chunk_size, timeout_opts, supervisor_pid) do
    http_options = HTTPUtils.http_options(timeout_opts)

    TaskUtils.tasks_with_order(content_length, chunk_size)
    |> Enum.map(fn {header, index} ->
      options =
        FileUtils.create_tmp_file!()
        |> HTTPUtils.options()

      request = HTTPUtils.request_for_url(url, header)

      TaskSupervisor.start_download_task(supervisor_pid, [
        request,
        http_options,
        options,
        index,
        self()
      ])
    end)
  end

  @doc """
  Handles responses from chunk download tasks.

  Stores response in state and then checks if all chunks are downloaded.
  If they are downloaded merges chunk files in to one and sends `{:ok, path_to_save}` to  parent pid and starts killing itself..

  Sends error request to parent pid in error cases.

  Returns `{:noreply, state}` if response is correct and chunk downloading started.
  Returns `{:stop, :normal, state}` if there was an error or server doesn't support chunk downloading.
  """
  @spec handle_chunk_response({:ok, any, any} | {:error, :server_error, any()}, map()) ::
          {:stop, :normal, map()} | {:noreply, map()}
  def handle_chunk_response({:ok, path_to_file, index}, %{chunks: chunks} = state) do
    state
    |> Map.put(:chunks, chunks ++ [{path_to_file, index}])
    |> case do
      %{
        chunks_count: chunks_count,
        chunks: chunks,
        path_to_save: path_to_save,
        parent_pid: parent_pid
      } = new_state
      when length(chunks) == chunks_count ->
        TaskUtils.extract_chunk_files(chunks)
        |> FileUtils.merge_files!(path_to_save)

        Logger.info("Successfully merged chunk files in to: #{path_to_save}")

        send(parent_pid, {:ok, path_to_save})
        {:stop, :normal, new_state}

      new_state ->
        #
        # Chunks downloading not complete, hibernate and wait for next responses.
        {:noreply, new_state, :hibernate}
    end
  end

  def handle_chunk_response(
        {:error, :server_error, reason},
        %{parent_pid: parent_pid} = state
      ) do
    send(parent_pid, {:error, :server_error, reason})
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:head_request, response}, state), do: handle_head_response(response, state)

  @impl true
  def handle_cast({:chunk_request, response}, state), do: handle_chunk_response(response, state)

  @impl true
  def terminate(reason, %{supervisor_pid: supervisor_pid} = state) do
    Logger.info(
      "HTTPClient is terminating with reason: #{inspect(reason)}, state: #{inspect(state)}"
    )

    TaskSupervisor.stop(supervisor_pid)
    state
  end
end
