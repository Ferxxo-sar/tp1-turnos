require "test_helper"

class ClientPortalTest < ActionDispatch::IntegrationTest
  setup do
    @client = clients(:one)
    @slot = 3.days.from_now.change(hour: 11, min: 0)
    @slot += 1.day if @slot.sunday?
  end

  def sign_in(client = @client)
    post login_path, params: { email: client.email, password: "password123" }
  end

  test "la home lista profesionales y servicios" do
    get root_path
    assert_response :success
    assert_select "h3", text: stylists(:one).name
    assert_match services(:one).name, response.body
  end

  test "mis turnos requiere login" do
    get appointments_path
    assert_redirected_to login_path
  end

  test "login con credenciales incorrectas" do
    post login_path, params: { email: @client.email, password: "mala" }
    assert_response :unprocessable_content
  end

  test "registro de un cliente nuevo" do
    assert_difference "Client.count", 1 do
      post signup_path, params: { client: { name: "Nuevo", email: "nuevo@mail.com", password: "secret123", password_confirmation: "secret123" } }
    end
    assert_redirected_to new_appointment_path
  end

  test "reservar un turno congela el precio y envía el email" do
    sign_in
    assert_enqueued_emails 1 do
      assert_difference "Appointment.count", 1 do
        post appointments_path, params: { appointment: {
          stylist_id: stylists(:one).id, date: @slot.to_date.iso8601, time: "11:00",
          service_ids: [ services(:one).id, services(:two).id ]
        } }
      end
    end

    appointment = Appointment.last
    assert_redirected_to appointment_path(appointment)
    assert_equal @client, appointment.client
    assert_equal @slot, appointment.scheduled_at
    assert_equal services(:one).price + services(:two).price, appointment.total
  end

  test "no se puede reservar sin servicios" do
    sign_in
    assert_no_difference "Appointment.count" do
      post appointments_path, params: { appointment: { stylist_id: stylists(:one).id, date: @slot.to_date.iso8601, time: "11:00" } }
    end
    assert_response :unprocessable_content
  end

  test "no se puede reservar un horario ocupado" do
    sign_in
    taken = appointments(:one)
    assert_no_difference "Appointment.count" do
      post appointments_path, params: { appointment: {
        stylist_id: taken.stylist_id, date: taken.scheduled_at.to_date.iso8601,
        time: taken.scheduled_at.strftime("%H:%M"), service_ids: [ services(:one).id ]
      } }
    end
    assert_match "el estilista ya tiene un turno en ese horario", response.body
  end

  test "el cliente puede cancelar su turno" do
    sign_in
    patch cancel_appointment_path(appointments(:one))
    assert_redirected_to appointments_path
    assert_equal "cancelled", appointments(:one).reload.status
  end

  test "un cliente no ve turnos ajenos" do
    sign_in
    get appointment_path(appointments(:two))
    assert_response :not_found
  end
end
