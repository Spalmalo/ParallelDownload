defmodule ParallelDownload.DownloadTask do
  require Logger
  alias ParallelDownload.HTTPUtils

  def chunk_request(url, headers, chunk_file_path, index) do
    opts = [
      {:stream, chunk_file_path |> String.to_charlist()},
      {:body_format, :binary}
    ]

    Logger.info("Start download chunk by url: #{url},
      headers: #{inspect(headers, pretty: true)},
      chunk file path: #{inspect(chunk_file_path)},
      index: #{index}")

    request = HTTPUtils.request_for_url(url, headers)

    :httpc.request(:get, request, [], opts)
    |> case do
      {:ok, :saved_to_file} ->
        Logger.info("Successfully saved to file #{inspect(chunk_file_path)}")
        {:ok, chunk_file_path, index}

      {:error, reason} ->
        Logger.error("Error of chunk downloading by url: #{url}, error: #{inspect(reason)} ")
        {:error, reason}
    end
  end
end
