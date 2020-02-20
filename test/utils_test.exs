defmodule ParallelDownload.UtilsTest do
  use ExUnit.Case

  alias ParallelDownload.HTTPUtils

  describe "HTTPUtils module functions tests ::" do
    test "should return list of headers" do
      headers = HTTPUtils.headers_for_chunks(1000, 100)
      assert length(headers) == 10

      headers = HTTPUtils.headers_for_chunks(1010, 100)
      assert length(headers) == 11

      headers = HTTPUtils.headers_for_chunks(100, 100)
      assert length(headers) == 1
    end

    test "should raise ArgumentError when non string parameter is send to request_for_url function" do
      assert_raise FunctionClauseError, fn -> HTTPUtils.request_for_url('akaka') end
    end

    test "extracts filename form url" do
      assert "100Mb.dat" == HTTPUtils.filename_from_url("http://ovh.net/files/100Mb.dat")

      assert "100Mb.dat" ==
               HTTPUtils.filename_from_url("http://ovh.net/files/100Mb.dat?test=aa&b=1")

      assert "100Mb" == HTTPUtils.filename_from_url("http://ovh.net/files/100Mb")
    end

    test "url validation tests" do
      assert :ok == HTTPUtils.valid_url("http://vk.com")
      assert :ok == HTTPUtils.valid_url("https://google.com")
      assert :ok == HTTPUtils.valid_url("https://google.com?some&rum=aaa")
      assert :ok == HTTPUtils.valid_url("https://google.com?some&rum=aaa")

      assert {:error, :url_not_valid} == HTTPUtils.valid_url("google.com")
      assert {:error, :url_not_valid} == HTTPUtils.valid_url("ftp://google.com")
    end
  end
end
