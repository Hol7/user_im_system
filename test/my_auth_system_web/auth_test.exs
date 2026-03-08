defmodule MyAuthSystem.AuthTest do
  use MyAuthSystem.DataCase, async: true
  alias MyAuthSystem.Auth
  alias MyAuthSystem.Accounts.User

  setup do
    user = user_fixture()
    %{user: user}
  end

  describe "authenticate/2" do
    test "returns user with valid credentials", %{user: user} do
      assert {:ok, authenticated_user} = Auth.authenticate(user.email, "password123")
      assert authenticated_user.id == user.id
    end

    test "returns error with invalid password", %{user: user} do
      assert {:error, :invalid_credentials} = Auth.authenticate(user.email, "wrongpass")
    end

    test "returns error with non-existent email" do
      assert {:error, :invalid_credentials} =
               Auth.authenticate("nonexistent@example.com", "password123")
    end
  end

  describe "generate_otp/2" do
    test "generates valid OTP for login" do
      user = user_fixture()
      otp = Auth.generate_otp(user.id, :login)

      assert otp.user_id == user.id
      assert otp.purpose == :login
      assert DateTime.diff(otp.expires_at, DateTime.utc_now(), :minute) == 5
      assert otp.code_hash != nil
    end
  end
end

defp user_fixture(attrs \\ %{}) do
  {:ok, user} =
    attrs
    |> Enum.into(%{
      email: "user#{System.unique_integer([:positive, :monotonic])}@example.com",
      password: "password123",
      password_confirmation: "password123"
    })
    |> MyAuthSystem.Accounts.create_user()

  user
end
