require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid session cookie" do
    user = users(:one)
    session = user.sessions.create!

    cookies.signed[:session_id] = session.id
    connect

    assert_equal user, connection.current_user
  end

  test "rejects connection without session cookie" do
    assert_reject_connection do
      connect
    end
  end

  test "rejects connection with invalid session id" do
    cookies.signed[:session_id] = "invalid"
    assert_reject_connection do
      connect
    end
  end
end
