defmodule MyAuthSystem.Notifications.BrevoTest do
  use ExUnit.Case, async: true
  alias MyAuthSystem.Notifications.Brevo

  @moduletag :integration

  test "send_otp_email returns ok with valid config" do
    # Skip in CI or if no API key
    if System.get_env("BREVO_API_KEY") do
      assert {:ok, response} =
               Brevo.send_otp_email(
                 "test@example.com",
                 "Test User",
                 "123456"
               )

      assert response["messageId"] != nil
    else
      # Skip test
      :ok
    end
  end
end
