require "test_helper"

class AdminUserTest < ActiveSupport::TestCase
  test "valid with name, email and password" do
    admin = AdminUser.new(name: "Nuevo Admin", email: "nuevo@example.com", password: "secret123")
    assert admin.valid?
  end

  test "invalid without email" do
    admin = AdminUser.new(name: "Nuevo Admin", password: "secret123")
    assert_not admin.valid?
  end

  test "invalid with duplicate email" do
    admin = AdminUser.new(name: "Otro", email: admin_users(:one).email, password: "secret123")
    assert_not admin.valid?
  end
end
