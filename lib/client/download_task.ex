defmodule ParallelDownload.DownloadTask do
  alias ParallelDownload.HTTPUtils

  def chunk_request(url, headers, chunk_file_path, index) do
    opts = [
      {:stream, chunk_file_path |> String.to_charlist()},
      {:body_format, :binary}
    ]

    request = HTTPUtils.request_for_url(url, headers)

    :httpc.request(:get, request, [], opts)
    |> case do
      {:ok, :saved_to_file} ->
        {:ok, chunk_file_path, index}
    end
  end
end
