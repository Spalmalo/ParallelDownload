defmodule ParallelDownload.DownloadTask do
  @moduledoc """
  Module for chunk download request task.
  Uses transient restart strategy.
  """
  use Task, restart: :transient
  require Logger
  alias ParallelDownload.HTTPUtils

  @spec start_link([any]) :: {:ok, pid}
  def start_link(args) do
    Task.start_link(__MODULE__, :run_request, args)
  end

  @spec run_request(tuple(), keyword(), keyword(), non_neg_integer(), pid()) ::
          {:ok, binary(), non_neg_integer()} | {:error, atom(), term()}
  def run_request(request, http_opts, opts, index, client_pid) do
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
        GenServer.call(client_pid, {:chunk_request, {:ok, chunk_file_path, index}})

      {:error, reason} ->
        Logger.error(
          "Error of chunk downloading by request: #{inspect(request, pretty: true)}, error: #{
            inspect(reason)
          } "
        )

        GenServer.call(client_pid, {:chunk_request, {:error, :server_error, reason}})
    end
  end
end
