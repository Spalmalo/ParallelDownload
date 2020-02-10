defmodule ParallelDownload.TaskUtils do
  alias ParallelDownload.HTTPUtils

  def tasks_with_order(content_length, chunk_size) do
    HTTPUtils.headers_for_chunks(content_length, chunk_size)
    |> Enum.with_index()
  end

  def extract_chunk_files(results) do
    results
    |> Enum.sort(fn {_, index1}, {_, index2} -> index1 < index2 end)
    |> Enum.map(fn {p, _} -> p end)
  end
end
