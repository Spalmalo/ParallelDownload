defmodule ParallelDownload.HeadTask do
  @moduledoc """
  Module for HEAD HTTP request.
  """
  require Logger
  alias ParallelDownload.HTTPUtils

  @doc """
  Makes HEAD request by given request tuple to know is url reachable,
  does server support multipart download and to know content length of the target file.
  Returns {boolean, boolean, pos_integer}.

  First element of tuple shows is url is reachable, it is true if server returns 200 OK.
  Second element of tuple shows server accepts range requests. It is true if server returns "accept-ranges: bytes".
  Third element of tuple is content-length of file in bytes.
  """
  @spec head_request(tuple(), keyword()) :: {boolean(), boolean(), non_neg_integer()}
  def head_request(request, http_opts) do
    Logger.info("Start HEAD request: #{inspect(request)} ")

    :httpc.request(:head, request, http_opts, [])
    |> case do
      {:ok, {status, response_data, _} = response} ->
        Logger.info(
          "Response for HEAD request #{inspect(request)}: #{inspect(response, pretty: true)}"
        )

        {
          HTTPUtils.http_status_ok?(status),
          HTTPUtils.accept_range?(response_data),
          HTTPUtils.content_length(response_data)
        }

      {:error, reason} ->
        Logger.error(
          "Error for head request: #{inspect(request, pretty: true)}, error: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
