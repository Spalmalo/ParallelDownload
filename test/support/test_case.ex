defmodule ParallelDownload.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import ParallelDownload.TestCase
    end
  end

  setup do
    tmp_dir = Application.get_env(:parallel_download, :tmp_dir_path)
    # clean tmp dir
    if File.exists?(tmp_dir) do
      File.rm_rf(tmp_dir)
    end

    results_dir = Application.get_env(:parallel_download, :results_dir_path_for_tests)

    unless File.exists?(results_dir) do
      File.mkdir!(results_dir)
    end

    {:ok, results_dir: results_dir}
  end
end
