require "test_helper"

class AppointmentServiceTest < ActiveSupport::TestCase
  test "sets price_at_booking from the service price when not given" do
    appointment_service = AppointmentService.new(appointment: appointments(:one), service: services(:two))

    assert appointment_service.valid?
    assert_equal services(:two).price, appointment_service.price_at_booking
  end

  test "invalid when the same service is added twice to the same appointment" do
    duplicate = AppointmentService.new(appointment: appointments(:one), service: services(:one))

    assert_not duplicate.valid?
  end
end
