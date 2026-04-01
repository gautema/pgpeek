defmodule Pgpeek.AuthTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Auth
  alias Pgpeek.Schemas.User

  defp create_user(attrs \\ %{}) do
    default = %{email: "admin@pgpeek.local", password: "password123"}

    %User{}
    |> User.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  describe "seed_admin_user!/0" do
    test "creates admin user when users table is empty and password is set" do
      Application.put_env(:pgpeek, :admin_password, "testpassword123")

      Auth.seed_admin_user!()

      user = Repo.get_by(User, email: "admin@pgpeek.local")
      assert user
      assert Bcrypt.verify_pass("testpassword123", user.password_hash)
    after
      Application.delete_env(:pgpeek, :admin_password)
    end

    test "does not create user when users table already has entries" do
      create_user()
      Application.put_env(:pgpeek, :admin_password, "anotherpassword")

      Auth.seed_admin_user!()

      assert Repo.aggregate(User, :count) == 1
    after
      Application.delete_env(:pgpeek, :admin_password)
    end

    test "does nothing when no admin password is configured" do
      Application.delete_env(:pgpeek, :admin_password)

      Auth.seed_admin_user!()

      assert Repo.aggregate(User, :count) == 0
    end

    test "does nothing when admin password is empty string" do
      Application.put_env(:pgpeek, :admin_password, "")

      Auth.seed_admin_user!()

      assert Repo.aggregate(User, :count) == 0
    after
      Application.delete_env(:pgpeek, :admin_password)
    end
  end

  describe "authenticate/2" do
    test "returns ok tuple with valid credentials" do
      user = create_user()

      assert {:ok, authenticated} = Auth.authenticate("admin@pgpeek.local", "password123")
      assert authenticated.id == user.id
    end

    test "returns error with wrong password" do
      create_user()

      assert {:error, :invalid_password} = Auth.authenticate("admin@pgpeek.local", "wrongpassword")
    end

    test "returns error when user not found" do
      assert {:error, :not_found} = Auth.authenticate("nobody@test.com", "password123")
    end
  end

  describe "get_user!/1" do
    test "returns user by id" do
      user = create_user()
      assert Auth.get_user!(user.id).id == user.id
    end

    test "raises when user not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Auth.get_user!(999)
      end
    end
  end

  describe "record_login/1" do
    test "updates last_login_at" do
      user = create_user()
      assert user.last_login_at == nil

      {:ok, updated} = Auth.record_login(user)
      assert updated.last_login_at != nil
    end
  end
end
