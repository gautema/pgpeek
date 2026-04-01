defmodule Pgpeek.Schemas.UserTest do
  use Pgpeek.DataCase, async: true

  alias Pgpeek.Schemas.User

  describe "changeset/2" do
    test "valid attributes" do
      changeset = User.changeset(%User{}, %{email: "admin@test.com", password: "password123"})
      assert changeset.valid?
    end

    test "hashes the password" do
      changeset = User.changeset(%User{}, %{email: "admin@test.com", password: "password123"})
      assert changeset.changes.password_hash
      assert changeset.changes.password_hash != "password123"
      assert Bcrypt.verify_pass("password123", changeset.changes.password_hash)
    end

    test "requires email" do
      changeset = User.changeset(%User{}, %{password: "password123"})
      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password" do
      changeset = User.changeset(%User{}, %{email: "admin@test.com"})
      refute changeset.valid?
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password to be at least 8 characters" do
      changeset = User.changeset(%User{}, %{email: "admin@test.com", password: "short"})
      refute changeset.valid?
      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "does not hash password when changeset is invalid" do
      changeset = User.changeset(%User{}, %{email: "admin@test.com", password: "short"})
      refute Map.has_key?(changeset.changes, :password_hash)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
