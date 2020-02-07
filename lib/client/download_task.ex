defmodule ParallelDownload.DownloadTask do
  require Logger
  alias ParallelDownload.HTTPUtils

  @spec chunk_request(tuple(), keyword(), keyword(), non_neg_integer()) ::
          {:ok, binary(), non_neg_integer()} | {:error, atom(), term()}
  def chunk_request(request, http_opts, opts, index) do
    Logger.info(
      "Start download chunk by request: #{inspect(request, pretty: true)}, http_opts: #{
        inspect(http_opts, pretty: true)
      }, index: #{index}, opts: #{inspect(opts, pretty: true)}"
    )

    :httpc.request(:get, request, http_opts, opts)
    |> case do
      {:ok, :saved_to_file} ->
        chunk_file_path = HTTPUtils.chunk_filepath_from_options(opts)
        Logger.info("Successfully saved to file #{inspect(chunk_file_path)}")
        {:ok, chunk_file_path, index}

      {:error, reason} ->
        Logger.error(
          "Error of chunk downloading by request: #{inspect(request, pretty: true)}, error: #{
            inspect(reason)
          } "
        )

        {:error, :server_error, reason}
    end
  end
end
