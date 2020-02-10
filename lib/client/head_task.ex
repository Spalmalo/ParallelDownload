defmodule ParallelDownload.HeadTask do
  @moduledoc """
  Module for HEAD HTTP request task.
  Uses transient restart strategy.
  """
  use Task, restart: :transient
  require Logger
  alias ParallelDownload.HTTPUtils

  def start_link(args) do
    Task.start_link(__MODULE__, :run_request, args)
  end

  @doc """
  Makes HEAD request by given request tuple to know is url reachable,
  does server support multipart download and to know content length of the target file.
  Sends {:head_request, pid, {boolean, boolean, pos_integer}} to given clint_pid.

  First element of tuple shows is url is reachable, it is true if server returns 200 OK.
  Second element of tuple shows server accepts range requests. It is true if server returns "accept-ranges: bytes".
  Third element of tuple is content-length of file in bytes.
  """
  @spec run_request(tuple(), keyword(), pid) :: {:ok, pid}
  def run_request(request, http_opts, client_pid) do
    Logger.info("Start HEAD request: #{inspect(request)} ")

    :httpc.request(:head, request, http_opts, [])
    |> case do
      {:ok, {status, response_data, _} = response} ->
        Logger.info(
          "Response for HEAD request #{inspect(request)}: #{inspect(response, pretty: true)}"
        )

        GenServer.call(
          client_pid,
          {:head_request,
           {
             HTTPUtils.http_status_ok?(status),
             HTTPUtils.accept_range?(response_data),
             HTTPUtils.content_length(response_data)
           }}
        )

      {:error, reason} ->
        Logger.error(
          "Error for head request: #{inspect(request, pretty: true)}, error: #{inspect(reason)}"
        )

        GenServer.call(client_pid, {:head_request, {:error, reason}})
    end

    {:ok, self()}
  end
end
