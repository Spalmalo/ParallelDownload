defmodule ParallelDownload.FileUtils do
  @moduledoc """
  Files related functions.
  """

  @spec validate_dir?(binary()) ::
          :ok | {:error, :enoent} | {:error, :no_access} | {:error, :not_directory}
  def validate_dir?(path) do
    case File.exists?(path) do
      true ->
        case File.stat!(path) do
          %{access: access} when access not in [:write, :read_write] -> {:error, :no_access}
          %{type: type} when type in [:regular] -> {:error, :not_directory}
          _ -> :ok
        end

      false ->
        {:error, :enoent}
    end
  end

  @doc """
  Creates temporary file and returns it's Path.t()
  Raises File.Error for file operation errors.
  """
  @spec create_tmp_file!() :: Path.t()
  def create_tmp_file!() do
    path = create_tmp_file_path()
    File.touch!(path)
    path
  end

  @doc """
  Returns temporary file path.
  """
  @spec create_tmp_file_path :: Path.t()
  def create_tmp_file_path() do
    Path.join(tmp_dir_path(), random_filename())
  end

  @doc """
  Merges content of chunk files in to final one.
  If file already exists by given path recreates it.
  Saves result file by given path.
  Raises File.Error for file operation errors.
  Returns result file path.
  """
  @spec merge_files!(list(), binary()) :: :ok
  def merge_files!(files, result_file_path) do
    if File.exists?(result_file_path) do
      File.rm!(result_file_path)
      File.touch!(result_file_path)
    end

    files
    |> Enum.each(fn tmp_path ->
      File.stream!(tmp_path, [:binary], 2048)
      |> Stream.into(File.stream!(result_file_path, [:append, :binary], 2048))
      |> Stream.run()
    end)

    :ok
  end

  @doc """
  Removes given files.
  """
  @spec remove_tmp_files(any) :: :ok
  def remove_tmp_files(files) do
    files
    |> Enum.each(fn tmp_path -> File.rm(tmp_path) end)

    :ok
  end

  @doc """
  Creates application temporary directory where downloaded chunk files stored.
  Raises File.Error for file operation errors.
  """
  @spec create_tmp_dir! :: nil | :ok
  def create_tmp_dir! do
    unless File.exists?(tmp_dir_path()) do
      File.mkdir!(tmp_dir_path())
    end
  end

  def random_filename do
    # TODO make random more random
    Enum.random(1..10_000_000) |> Integer.to_string()
  end

  defp tmp_dir_path do
    Application.get_env(:parallel_download, :tmp_dir_path)
  end
end
