require "test_helper"

class StylistTest < ActiveSupport::TestCase
  test "invalid without specialty" do
    stylist = Stylist.new(name: "Nuevo Estilista")
    assert_not stylist.valid?
  end

  test "valid with name and specialty" do
    stylist = Stylist.new(name: "Nuevo Estilista", specialty: "Barbería")
    assert stylist.valid?
  end
end
