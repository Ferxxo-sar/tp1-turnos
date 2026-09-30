require "test_helper"

class AppointmentMailerTest < ActionMailer::TestCase
  test "confirmación de turno" do
    appointment = appointments(:one)
    mail = AppointmentMailer.confirmation(appointment)

    assert_equal [ appointment.client.email ], mail.to
    assert_match "turno reservado", mail.subject
    assert_match appointment.stylist.name, mail.body.encoded
  end
end
