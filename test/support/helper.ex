defmodule ParallelDownload.TestHelper do
  @doc """
  Returns MD5 hash of file by given file path.
  """
  @spec md5(binary | Path.t()) :: binary()
  def md5(filepath) do
    File.stream!(filepath, [], 2048)
    |> Enum.reduce(:crypto.hash_init(:md5), fn line, acc ->
      :crypto.hash_update(acc, line)
    end)
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end
end
