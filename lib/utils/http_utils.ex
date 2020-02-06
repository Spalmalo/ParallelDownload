defmodule ParallelDownload.HTTPUtils do
  @moduledoc """
  Helper functions to work with :httpc headers and requests.
  All String.t() values converted to charlist because :httpc doesn't know what String it is.
  """

  @doc """
  Not perfect validating of given url
  """
  @spec valid_url(binary | URI.t()) :: :ok | {:error, :url_not_valid}
  def valid_url(url) do
    case URI.parse(url) do
      %{scheme: nil} -> {:error, :url_not_valid}
      %{scheme: scheme} when scheme not in ["http", "https"] -> {:error, :url_not_valid}
      %{host: nil} -> {:error, :url_not_valid}
      _ -> :ok
    end
  end

  @doc """
  Returns request struct for httpc for given url and headers list.
  """
  @spec request_for_url(binary(), list) :: {charlist(), list}
  def request_for_url(url, headers \\ []) when is_binary(url) do
    {
      url |> String.to_charlist(),
      headers
    }
  end

  @doc """
  Computes byte offsets and returns headers list for range request compatible with :httpc.
  If chunk_size bigger than content_length returns one header for range from 0 to chunk_size.
  Returns empty list if content_length is 0.
  Returns list with tuples {"Range" , "bytes=offset-length"}.
  """
  @spec headers_for_chunks(pos_integer(), pos_integer()) :: [{binary, binary}]
  def headers_for_chunks(0, _), do: []

  def headers_for_chunks(content_length, 0),
    do: headers_for_chunks(content_length, content_length)

  def headers_for_chunks(content_length, chunk_size) when content_length < chunk_size,
    do: [range_header(0, content_length)]

  def headers_for_chunks(content_length, chunk_size) do
    number_of_chunks =
      if(rem(content_length, chunk_size) > 0) do
        div(content_length, chunk_size) + 1
      else
        div(content_length, chunk_size)
      end

    1..number_of_chunks
    |> Enum.map(fn i -> calculate_offset(i, chunk_size, content_length) end)
    |> Enum.map(fn {offset, ll} -> range_header(offset, ll) end)
  end

  @doc """
  Looks for "accept-ranges" header.
  Returns true if header value is "bytes".
  Returns false if header value is "none" or header value is not found.
  """
  @spec accept_range?([tuple()]) :: boolean
  def accept_range?(data) do
    data
    |> Enum.find(fn {key, _} -> key == 'accept-ranges' end)
    |> case do
      {_, 'bytes'} -> true
      {_, 'none'} -> false
      nil -> false
    end
  end

  @doc """
  Returns true if response status is 200.
  Returns false in other cases.
  """
  @spec http_status_ok?({any, pos_integer(), any}) :: boolean
  def http_status_ok?(status) do
    # TODO handle redirect statuses
    case status do
      {_, 200, _} -> true
      {_, _, _} -> false
    end
  end

  @doc """
  Returns "content-length" header value.
  """
  @spec content_length([tuple()]) :: pos_integer()
  def content_length(data) do
    data
    |> Enum.find(fn {key, _} -> key == 'content-length' end)
    |> elem(1)
    |> List.to_integer()
  end

  @doc """
  Tries to extract filename form given url.
  Returns filename in success or nil.
  """
  @spec filename_from_url(binary() | URI.t()) :: nil | binary()
  def filename_from_url(url) do
    URI.parse(url)
    |> Map.from_struct()
    |> get_in([:path])
    |> Path.basename()
    |> case do
      "" -> nil
      name -> name
    end
  end

  defp calculate_offset(i, chunk_size, content_length) do
    offset = chunk_size * (i - 1)

    if(offset + chunk_size < content_length) do
      {offset, offset + chunk_size - 1}
    else
      {offset, content_length - 1}
    end
  end

  defp range_header(offset, content_length) do
    {
      'Range',
      "bytes=#{offset}-#{content_length}" |> String.to_charlist()
    }
  end
end
