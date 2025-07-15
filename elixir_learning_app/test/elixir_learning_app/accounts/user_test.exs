defmodule ElixirLearningApp.Accounts.UserTest do
  use ElixirLearningApp.DataCase

  alias ElixirLearningApp.Accounts.User

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{email: "test@example.com", name: "Test User"}
      changeset = User.changeset(%User{}, attrs)
      
      assert changeset.valid?
      assert changeset.changes.email == "test@example.com"
      assert changeset.changes.name == "Test User"
    end

    test "requires email" do
      attrs = %{name: "Test User"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "requires name" do
      attrs = %{email: "test@example.com"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "validates email format" do
      attrs = %{email: "invalid-email", name: "Test User"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "validates email format with spaces" do
      attrs = %{email: "test @example.com", name: "Test User"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "validates email length" do
      long_email = String.duplicate("a", 250) <> "@example.com"
      attrs = %{email: long_email, name: "Test User"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).email
    end

    test "validates name length" do
      attrs = %{email: "test@example.com", name: ""}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "validates name max length" do
      long_name = String.duplicate("a", 256)
      attrs = %{email: "test@example.com", name: long_name}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end
  end
end