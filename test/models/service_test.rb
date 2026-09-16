require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "invalid with duration_minutes zero" do
    service = Service.new(name: "Peinado", duration_minutes: 0, price: 100, category: categories(:one))
    assert_not service.valid?
  end

  test "invalid with negative price" do
    service = Service.new(name: "Peinado", duration_minutes: 20, price: -1, category: categories(:one))
    assert_not service.valid?
  end

  test "valid with positive duration and price" do
    service = Service.new(name: "Peinado", duration_minutes: 20, price: 100, category: categories(:one))
    assert service.valid?
  end
end
