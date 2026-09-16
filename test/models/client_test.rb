require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "valid with name, email and password" do
    client = Client.new(name: "Nuevo Cliente", email: "nuevo.cliente@example.com", password: "secret123")
    assert client.valid?
  end

  test "invalid with duplicate email" do
    client = Client.new(name: "Otro", email: clients(:one).email, password: "secret123")
    assert_not client.valid?
  end

  test "regenerate_api_token! assigns a new token" do
    client = clients(:one)
    original_token = client.api_token

    client.regenerate_api_token!

    assert_not_equal original_token, client.api_token
  end
end
