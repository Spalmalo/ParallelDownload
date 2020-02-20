defmodule ParallelDownload.TaskUtils do
  alias ParallelDownload.HTTPUtils

  @doc """
  Returns list of `Range` headers with calculated range in bytes wrapped in tuple with index.
  Index needed to keep order for future chunk files merge.
  """
  @spec tasks_with_order(pos_integer(), pos_integer()) :: [{any(), integer()}]
  def tasks_with_order(content_length, chunk_size) do
    HTTPUtils.headers_for_chunks(content_length, chunk_size)
    |> Enum.with_index()
  end

  @doc """
  Returns list with file pathes.
  """
  @spec extract_chunk_files(any()) :: [any()]
  def extract_chunk_files(results) do
    results
    |> Enum.sort(fn {_, index1}, {_, index2} -> index1 < index2 end)
    |> Enum.map(fn {p, _} -> p end)
  end
end
