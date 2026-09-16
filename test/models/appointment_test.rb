require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  test "invalid with a scheduled_at in the past" do
    appointment = Appointment.new(client: clients(:one), stylist: stylists(:one), scheduled_at: 1.day.ago)
    assert_not appointment.valid?
  end

  test "invalid when the stylist already has an appointment at that exact time" do
    existing = appointments(:one)
    conflicting = Appointment.new(
      client: clients(:two),
      stylist: existing.stylist,
      scheduled_at: existing.scheduled_at
    )

    assert_not conflicting.valid?
    assert_includes conflicting.errors[:scheduled_at], "el estilista ya tiene un turno en ese horario"
  end

  test "valid when the same stylist has a free slot at a different time" do
    existing = appointments(:one)
    appointment = Appointment.new(
      client: clients(:two),
      stylist: existing.stylist,
      scheduled_at: existing.scheduled_at + 3.hours
    )

    assert appointment.valid?
  end

  test "a cancelled appointment does not block the slot" do
    existing = appointments(:one)
    existing.update!(status: "cancelled")

    appointment = Appointment.new(
      client: clients(:two),
      stylist: existing.stylist,
      scheduled_at: existing.scheduled_at
    )

    assert appointment.valid?
  end
end
