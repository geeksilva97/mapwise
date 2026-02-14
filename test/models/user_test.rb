require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "validates presence of email_address" do
    user = User.new(name: "Test", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "validates uniqueness of email_address" do
    existing = users(:one)
    user = User.new(name: "Test", email_address: existing.email_address, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "validates format of email_address" do
    user = User.new(name: "Test", email_address: "not-an-email", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "validates presence of name" do
    user = User.new(email_address: "test@example.com", password: "password123")
    user.name = ""
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "validates password minimum length" do
    user = User.new(name: "Test", email_address: "test@example.com", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "valid user with all attributes" do
    user = User.new(name: "Test User", email_address: "new@example.com", password: "password123")
    assert user.valid?
  end

  test "has many sessions" do
    user = users(:one)
    assert_respond_to user, :sessions
  end
end
