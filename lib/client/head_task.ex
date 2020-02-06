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
  @spec head_request(binary()) :: {boolean(), boolean(), pos_integer()}
  def head_request(url) when is_binary(url) do
    Logger.info("Start HEAD request for url: #{inspect(url)} ")
    request = HTTPUtils.request_for_url(url)
    {:ok, {status, response_data, _} = response} = :httpc.request(:head, request, [], [])

    Logger.info(
      "Response for HEAD request for url #{inspect(url)}: #{inspect(response, pretty: true)}"
    )

    {
      HTTPUtils.http_status_ok?(status),
      HTTPUtils.accept_range?(response_data),
      HTTPUtils.content_length(response_data)
    }
  end
end
