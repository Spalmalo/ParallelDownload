defmodule ParallelDownloadTest do
  use ParallelDownload.TestCase
  alias ParallelDownload.TestHelper

  @tag timeout: 300_000
  describe "Test downloading of files ::" do
    # test "test downloading of file from http://ovh.net/files", context do
    #   dir_path = context[:results_dir]

    #   assert {:ok, filepath} =
    #            ParallelDownload.download_file(
    #              "http://ovh.net/files/100Mb.dat",
    #              3_000_000,
    #              dir_path
    #            )

    #   assert Path.join(dir_path, "100Mb.dat") == filepath

    #   md5hash = TestHelper.md5(filepath)

    #   assert md5hash == "791d723ffb95645c567ccad31b4435b3"
    # end

    test "should return :server_error", context do
      dir_path = context[:results_dir]

      assert {:error, :server_error, _reason} =
               ParallelDownload.download_file(
                 "http://100Mb.dat",
                 3_000_000,
                 dir_path
               )
    end
  end

  @tag :files_test
  describe "File and directories related error cases" do
    test "test error cases" do
      assert {:error, :url_not_valid} =
               ParallelDownload.download_file("kakakak", 10000, "downloads")

      assert {:error, :enoent} =
               ParallelDownload.download_file("http://ovh.net/files/100Mb.dat", 10000, "rs")

      assert {:error, :not_directory} =
               ParallelDownload.download_file(
                 "http://ovh.net/files/100Mb.dat",
                 10000,
                 "test/test_helper.exs"
               )
    end
  end
end
