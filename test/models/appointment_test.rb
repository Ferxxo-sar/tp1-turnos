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

  test "invalid when it overlaps a longer appointment of the same stylist" do
    existing = appointments(:one) # 30 minutos desde las 10:00
    overlapping = Appointment.build_booking(
      { client: clients(:two), stylist: existing.stylist, scheduled_at: existing.scheduled_at.change(hour: 9, min: 30) },
      [ services(:two).id ] # 45 minutos: termina 10:15
    )

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:scheduled_at], "el estilista ya tiene un turno en ese horario"
  end

  test "valid when it starts right when another appointment ends" do
    existing = appointments(:one)
    appointment = Appointment.build_booking(
      { client: clients(:two), stylist: existing.stylist, scheduled_at: existing.scheduled_at + 30.minutes },
      [ services(:one).id ]
    )

    assert appointment.valid?
  end

  test "must fit the business hours" do
    day = business_time(3, hour: 9)
    { day.change(hour: 8) => "debe estar dentro del horario de atención (9 a 19 hs)",
      day.change(hour: 9, min: 15) => "debe coincidir con un bloque de 30 minutos",
      day.change(hour: 18, min: 30) => "debe estar dentro del horario de atención (9 a 19 hs)",
      Date.current.next_occurring(:sunday).in_time_zone.change(hour: 10) => "debe ser de lunes a sábado" }.each do |time, message|
      appointment = Appointment.build_booking({ client: clients(:two), stylist: stylists(:two), scheduled_at: time }, [ services(:two).id ])
      assert_not appointment.valid?, time.to_s
      assert_includes appointment.errors[:scheduled_at], message
    end
  end

  test "reschedule moves the appointment and leaves it pending" do
    appointment = appointments(:two)
    new_time = business_time(5, hour: 9, min: 30)

    assert appointment.reschedule(new_time)
    assert_equal new_time, appointment.reload.scheduled_at
    assert_equal "pending", appointment.status
  end

  test "a completed appointment can be closed even if it overlaps" do
    existing = appointments(:one)
    other = Appointment.create!(client: clients(:two), stylist: existing.stylist, scheduled_at: existing.scheduled_at + 1.hour)
    other.update_column(:scheduled_at, existing.scheduled_at)

    assert other.update(status: "completed")
  end
end
