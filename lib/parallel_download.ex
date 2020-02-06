defmodule ParallelDownload do
  @moduledoc """
  Parallel Downloader allows you to download bug files in chunks and in parallel way.
  Uses :httpc.
  """

  require Logger

  alias ParallelDownload.HTTPUtils
  alias ParallelDownload.FileUtils
  alias ParallelDownload.Supervisor

  @doc """
  Downloads and saves file from given url to the given path.
  """
  def download_file(url, chunk_size_bytes, dir_to_download, filename \\ "")
      when is_binary(url) and is_integer(chunk_size_bytes) and is_binary(dir_to_download) and
             is_binary(filename) do
    with :ok <- HTTPUtils.valid_url(url),
         :ok <- FileUtils.validate_dir?(dir_to_download) do
      filepath = Path.join(dir_to_download, validate_filename(filename, url))

      start_client_under_supervisor(url, chunk_size_bytes, filepath)
    else
      {:error, :url_not_valid} -> {:error, :url_not_valid}
      {:error, :enoent} -> {:error, :enoent}
      {:error, :no_access} -> {:error, :no_access}
      {:error, :not_directory} -> {:error, :not_directory}
    end
  end

  def start_client_under_supervisor(url, chunk_size_bytes, filepath) do
    {:ok, pid} = Supervisor.start_client({self()})
    ref = Process.monitor(pid)
    GenServer.cast(pid, {:download, url, chunk_size_bytes, filepath})

    receive do
      {:ok, path_to_file} ->
        {:ok, path_to_file}

      {:error, reason} ->
        {:error, reason}

      {:DOWN, ^ref, _, _proc, reason} ->
        Process.demonitor(ref, [:flush])
        {:error, reason}
        # code
    end
  end

  defp validate_filename(filename, url) do
    case filename do
      "" -> HTTPUtils.filename_from_url(url) || FileUtils.random_filename()
      _ -> Path.basename(filename)
    end
  end
end
