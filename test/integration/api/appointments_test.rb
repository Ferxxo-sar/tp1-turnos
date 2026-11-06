require "test_helper"

class Api::AppointmentsTest < ActionDispatch::IntegrationTest
  def auth(client = clients(:one))
    { "Authorization" => "Bearer #{client.api_token}" }
  end

  def book(stylist:, at:, services:, client: clients(:two))
    Appointment.build_booking({ client: client, stylist: stylist, scheduled_at: at }, services.map(&:id)).tap(&:save!)
  end

  test "filtra próximos e historial" do
    past = Appointment.create!(client: clients(:one), stylist: stylists(:two), scheduled_at: business_time(3, hour: 9))
    past.update_columns(scheduled_at: 3.days.ago, status: "completed")

    get "/api/v1/appointments", headers: auth, params: { scope: "upcoming" }
    assert_equal [ appointments(:one).id ], response.parsed_body.map { |a| a["id"] }

    get "/api/v1/appointments", headers: auth, params: { scope: "history" }
    assert_equal [ past.id ], response.parsed_body.map { |a| a["id"] }
  end

  test "el detalle incluye duración, estado legible y si se puede cancelar" do
    get "/api/v1/appointments/#{appointments(:one).id}", headers: auth
    body = response.parsed_body
    assert_equal 30, body["duration_minutes"]
    assert_equal "Pendiente", body["status_label"]
    assert body["cancellable"]
  end

  test "no se puede ver el turno de otro cliente" do
    get "/api/v1/appointments/#{appointments(:two).id}", headers: auth
    assert_response :not_found
    assert_equal "No encontrado", response.parsed_body["error"]
  end

  test "reserva un domingo o fuera de horario" do
    sunday = Date.current.next_occurring(:sunday).in_time_zone.change(hour: 10)
    post "/api/v1/appointments", headers: auth, as: :json, params: {
      appointment: { stylist_id: stylists(:two).id, scheduled_at: sunday.iso8601, service_ids: [ services(:one).id ] }
    }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"]["scheduled_at"], "Fecha y hora debe ser de lunes a sábado"

    post "/api/v1/appointments", headers: auth, as: :json, params: {
      appointment: { stylist_id: stylists(:two).id, scheduled_at: business_time(3, hour: 21).iso8601, service_ids: [ services(:one).id ] }
    }
    assert_response :unprocessable_content
  end

  test "reserva superpuesta con un turno más largo" do
    start = business_time(4, hour: 11)
    book(stylist: stylists(:two), at: start, services: [ services(:two) ]) # 11:00 a 11:45

    post "/api/v1/appointments", headers: auth, as: :json, params: {
      appointment: { stylist_id: stylists(:two).id, scheduled_at: (start + 30.minutes).iso8601, service_ids: [ services(:one).id ] }
    }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"]["scheduled_at"], "Fecha y hora el estilista ya tiene un turno en ese horario"
  end

  test "reprogramar un turno" do
    new_time = business_time(3, hour: 16, min: 30)
    patch "/api/v1/appointments/#{appointments(:one).id}/reschedule", headers: auth, as: :json,
          params: { appointment: { scheduled_at: new_time.strftime("%Y-%m-%dT%H:%M") } }

    assert_response :success
    assert_equal new_time, appointments(:one).reload.scheduled_at
    assert_equal new_time.iso8601, response.parsed_body["scheduled_at"]
  end

  test "reprogramar un turno confirmado lo vuelve a dejar pendiente" do
    patch "/api/v1/appointments/#{appointments(:two).id}/reschedule", headers: auth(clients(:two)), as: :json,
          params: { appointment: { scheduled_at: business_time(5, hour: 9).iso8601 } }
    assert_response :success
    assert_equal "pending", response.parsed_body["status"]
  end

  test "reprogramar a un horario ocupado" do
    target = business_time(3, hour: 12)
    book(stylist: stylists(:one), at: target, services: [ services(:one) ])

    patch "/api/v1/appointments/#{appointments(:one).id}/reschedule", headers: auth, as: :json,
          params: { appointment: { scheduled_at: target.iso8601 } }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"].keys, "scheduled_at"
  end

  test "no se puede reprogramar un turno cancelado" do
    appointments(:one).cancel!
    patch "/api/v1/appointments/#{appointments(:one).id}/reschedule", headers: auth, as: :json,
          params: { appointment: { scheduled_at: business_time(3, hour: 12).iso8601 } }
    assert_response :unprocessable_content
    assert_equal "El turno ya no se puede reprogramar", response.parsed_body["error"]
  end

  test "disponibilidad para reprogramar no cuenta el propio turno" do
    appointment = appointments(:one)
    get "/api/v1/appointments/#{appointment.id}/availability", headers: auth,
        params: { date: appointment.scheduled_at.to_date.iso8601 }
    assert_response :success
    assert_includes response.parsed_body["slots"], appointment.scheduled_at.strftime("%H:%M")
    assert_equal 30, response.parsed_body["duration_minutes"]
  end

  test "disponibilidad con una fecha inválida" do
    get "/api/v1/appointments/#{appointments(:one).id}/availability", headers: auth, params: { date: "mañana" }
    assert_response :bad_request
    assert_equal "Fecha inválida, usar formato AAAA-MM-DD", response.parsed_body["error"]
  end
end
