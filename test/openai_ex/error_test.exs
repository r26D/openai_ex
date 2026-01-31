defmodule OpenaiEx.ErrorTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias OpenaiEx.Error

  describe "status_error/3" do
    test "when body is a map and body[\"error\"] is nil, returns Error with fallback message and does not raise" do
      response = %{status: 400, headers: []}
      body = %{"error" => nil}
      result = Error.status_error(400, response, body)
      assert %Error{} = result
      assert result.message == "HTTP 400"
      assert result.status_code == 400
      assert result.body == body
    end

    test "when body is a map and body[\"error\"][\"message\"] is missing, returns Error with fallback message" do
      response = %{status: 422, headers: []}
      body = %{"error" => %{"code" => "invalid"}}
      result = Error.status_error(422, response, body)
      assert %Error{} = result
      assert result.message == "HTTP 422"
      assert result.status_code == 422
    end

    test "when body has error with message, uses API message" do
      response = %{status: 400, headers: []}
      body = %{"error" => %{"message" => "Invalid parameter"}}
      result = Error.status_error(400, response, body)
      assert %Error{} = result
      assert result.message == "Invalid parameter"
      assert result.body["message"] == "Invalid parameter"
    end
  end
end
