defmodule ParallelDownload do
  @moduledoc """
  Parallel Downloader allows you to download bug files in chunks and in parallel way.
  Uses :httpc.
  """
  alias ParallelDownload.HTTPClient
  alias ParallelDownload.HTTPUtils
  alias ParallelDownload.FileUtils

  @doc """
  Downloads and saves file from given url to the given path.
  """
  def download_file(url, chunk_size_bytes, dir_to_download, filename \\ "")
      when is_binary(url) and is_integer(chunk_size_bytes) and is_binary(dir_to_download) and
             is_binary(filename) do
    with :ok <- HTTPUtils.valid_url(url),
         :ok <- FileUtils.validate_dir?(dir_to_download) do
      filepath = Path.join(dir_to_download, validate_filename(filename, url))
      HTTPClient.run_request(url, abs(chunk_size_bytes), filepath)
    else
      {:error, :url_not_valid} -> {:error, :url_not_valid}
      {:error, :enoent} -> {:error, :enoent}
      {:error, :no_access} -> {:error, :no_access}
      {:error, :not_directory} -> {:error, :not_directory}
    end
  end

  defp validate_filename(filename, url) do
    case filename do
      "" -> HTTPUtils.filename_from_url(url) || FileUtils.random_filename()
      _ -> Path.basename(filename)
    end
  end
end
