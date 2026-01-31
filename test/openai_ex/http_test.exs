defmodule OpenaiEx.HttpTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias OpenaiEx.Http

  describe "to_multi_part_form_data/2" do
    test "file field as {filename, content} sets filename in Content-Disposition from opts" do
      req = %{
        model: "whisper-1",
        file: {"audio.mp3", "binary audio content"}
      }

      multipart = Http.to_multi_part_form_data(req, [:file])

      body = Multipart.body_binary(multipart)
      assert body =~ ~r/content-disposition:\s*form-data;[^\r\n]*name="file"[^\r\n]*filename="audio\.mp3"/i
      assert body =~ "binary audio content"
      assert Multipart.content_type(multipart, "multipart/form-data") =~ "multipart/form-data"
      assert Multipart.content_length(multipart) > 0
    end

    test "file field as raw content uses empty filename in Content-Disposition" do
      req = %{
        model: "whisper-1",
        file: "raw bytes content"
      }

      multipart = Http.to_multi_part_form_data(req, [:file])

      body = Multipart.body_binary(multipart)
      # Multipart 0.6 includes filename="" when opts filename: "" is passed
      assert body =~ ~r/content-disposition:\s*form-data;[^\r\n]*name="file"([^\r\n]*filename="")?/i
      assert body =~ "raw bytes content"
      assert Multipart.content_length(multipart) > 0
    end

    test "file field as {path} uses file_field and does not raise" do
      tmp = System.tmp_dir!() |> Path.join("http_test_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp, "file on disk")

      req = %{
        model: "whisper-1",
        file: {tmp}
      }

      try do
        multipart = Http.to_multi_part_form_data(req, [:file])

        body = Multipart.body_binary(multipart)
        assert body =~ ~r/content-disposition:\s*form-data;[^\r\n]*name="file"/i
        assert body =~ "file on disk"
        assert Multipart.content_length(multipart) > 0
      after
        File.rm(tmp)
      end
    end

    test "text fields and file field together produce valid multipart" do
      req = %{
        model: "whisper-1",
        response_format: "json",
        file: {"pipeline.json", "{}"}
      }

      multipart = Http.to_multi_part_form_data(req, [:file])

      body = Multipart.body_binary(multipart)
      assert body =~ ~r/name="model"/
      assert body =~ "whisper-1"
      assert body =~ ~r/name="response_format"/
      assert body =~ "json"
      assert body =~ ~r/name="file"[^\r\n]*filename="pipeline\.json"/i
      assert body =~ "{}"
      assert Multipart.content_type(multipart, "multipart/form-data") =~ "boundary="
      assert Multipart.content_length(multipart) == byte_size(body)
    end
  end
end
