defmodule OpenaiEx.Chat.CompletionsTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use Patch

  alias OpenaiEx.Chat.Completions
  alias OpenaiEx.Http
  alias OpenaiEx.HttpSse

  defp openai do
    %OpenaiEx{
      token: "test",
      _http_headers: [{"Authorization", "Bearer test"}]
    }
  end

  defp base_request do
    %{
      model: "gpt-4",
      messages: [%{role: "user", content: "Hi"}]
    }
  end

  defp patch_http_post_capture do
    patch(Http, :post, fn _openai, _url, opts ->
      body = Keyword.get(opts, :json)
      send(self(), {:captured_body, body})
      {:ok, %{body: "{}", status: 200, headers: [], trailers: []}}
    end)
  end

  defp patch_http_sse_post_capture do
    patch(HttpSse, :post, fn _openai, _url, opts ->
      body = Keyword.get(opts, :json)
      send(self(), {:captured_body, body})
      {:ok,
       %{
         status: 200,
         headers: [],
         body_stream: Stream.map([], & &1),
         task_pid: self()
       }}
    end)
  end

  describe "create/2 (non-stream) request body" do
    test "GPT-4 unchanged: only max_tokens sends max_tokens, not max_completion_tokens" do
      patch_http_post_capture()
      req = Map.put(base_request(), :max_tokens, 100)
      assert {:ok, _} = Completions.create(openai(), req)
      assert_receive {:captured_body, body}
      assert Map.has_key?(body, :max_tokens)
      assert body.max_tokens == 100
      refute Map.has_key?(body, :max_completion_tokens)
    end

    test "GPT-5: only max_completion_tokens sends max_completion_tokens, not max_tokens" do
      patch_http_post_capture()
      req = Map.put(base_request(), :max_completion_tokens, 200)
      assert {:ok, _} = Completions.create(openai(), req)
      assert_receive {:captured_body, body}
      assert Map.has_key?(body, :max_completion_tokens)
      assert body.max_completion_tokens == 200
      refute Map.has_key?(body, :max_tokens)
    end

    test "prefer max_completion_tokens: both provided sends only max_completion_tokens" do
      patch_http_post_capture()
      req =
        base_request()
        |> Map.put(:max_tokens, 100)
        |> Map.put(:max_completion_tokens, 200)
      assert {:ok, _} = Completions.create(openai(), req)
      assert_receive {:captured_body, body}
      assert Map.has_key?(body, :max_completion_tokens)
      assert body.max_completion_tokens == 200
      refute Map.has_key?(body, :max_tokens)
    end

    test "reasoning_effort is included in body" do
      patch_http_post_capture()
      req = Map.put(base_request(), :reasoning_effort, "low")
      assert {:ok, _} = Completions.create(openai(), req)
      assert_receive {:captured_body, body}
      assert Map.has_key?(body, :reasoning_effort)
      assert body.reasoning_effort == "low"
    end

    test "max_input_tokens is never sent (whitelist drops it)" do
      patch_http_post_capture()
      req = Map.put(base_request(), :max_input_tokens, 1000)
      assert {:ok, _} = Completions.create(openai(), req)
      assert_receive {:captured_body, body}
      refute Map.has_key?(body, :max_input_tokens)
    end
  end

  describe "create/3 (stream: true) request body" do
    test "stream with max_completion_tokens does not send max_tokens" do
      patch_http_sse_post_capture()
      req = Map.put(base_request(), :max_completion_tokens, 200)
      assert {:ok, _} = Completions.create(openai(), req, stream: true)
      assert_receive {:captured_body, body}
      assert Map.has_key?(body, :max_completion_tokens)
      assert body.max_completion_tokens == 200
      refute Map.has_key?(body, :max_tokens)
      assert body.stream == true
    end

    test "stream with only max_tokens sends max_tokens (GPT-4)" do
      patch_http_sse_post_capture()
      req = Map.put(base_request(), :max_tokens, 100)
      assert {:ok, _} = Completions.create(openai(), req, stream: true)
      assert_receive {:captured_body, body}
      assert Map.has_key?(body, :max_tokens)
      assert body.max_tokens == 100
      refute Map.has_key?(body, :max_completion_tokens)
      assert body.stream == true
    end
  end
end
