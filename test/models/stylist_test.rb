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

  test "available slots skip the blocks taken by an appointment and its duration" do
    stylist = stylists(:two)
    day = business_time(4, hour: 11)
    Appointment.build_booking({ client: clients(:one), stylist: stylist, scheduled_at: day }, [ services(:two).id ]).save! # 11:00 a 11:45

    slots = stylist.available_slots(day.to_date).map { |slot| slot.strftime("%H:%M") }
    assert_equal "09:00", slots.first
    assert_equal "18:30", slots.last
    assert_not_includes slots, "11:00"
    assert_not_includes slots, "11:30"
    assert_includes slots, "12:00"

    long = stylist.available_slots(day.to_date, duration: 60).map { |slot| slot.strftime("%H:%M") }
    assert_not_includes long, "10:30"
    assert_equal "18:00", long.last
  end

  test "no slots on sundays" do
    assert_empty stylists(:one).available_slots(Date.current.next_occurring(:sunday))
  end
end
