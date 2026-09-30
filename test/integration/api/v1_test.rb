require "test_helper"

class Api::V1Test < ActionDispatch::IntegrationTest
  def auth(client = clients(:one))
    { "Authorization" => "Bearer #{client.api_token}" }
  end

  test "login devuelve un token nuevo" do
    post "/api/v1/login", params: { email: clients(:one).email, password: "password123" }, as: :json
    assert_response :success
    token = response.parsed_body["token"]
    assert_equal 48, token.length
    assert_equal token, clients(:one).reload.api_token
  end

  test "login inválido" do
    post "/api/v1/login", params: { email: clients(:one).email, password: "x" }, as: :json
    assert_response :unauthorized
  end

  test "listados públicos" do
    %w[stylists services categories].each do |resource|
      get "/api/v1/#{resource}"
      assert_response :success
      assert_kind_of Array, response.parsed_body
    end
  end

  test "disponibilidad excluye horarios tomados" do
    taken = appointments(:one)
    get "/api/v1/stylists/#{taken.stylist_id}/availability", params: { date: taken.scheduled_at.to_date.iso8601 }
    assert_response :success
    assert_not_includes response.parsed_body["slots"], taken.scheduled_at.strftime("%H:%M")
  end

  test "turnos requiere token" do
    get "/api/v1/appointments"
    assert_response :unauthorized
  end

  test "lista solo los turnos propios" do
    get "/api/v1/appointments", headers: auth
    ids = response.parsed_body.map { |a| a["id"] }
    assert_equal [ appointments(:one).id ], ids
  end

  test "reservar un turno" do
    time = 5.days.from_now.change(hour: 14)
    assert_difference "Appointment.count", 1 do
      post "/api/v1/appointments", headers: auth, as: :json, params: {
        appointment: { stylist_id: stylists(:two).id, scheduled_at: time.iso8601, service_ids: [ services(:one).id ] }
      }
    end
    assert_response :created
    assert_equal services(:one).price.to_f, response.parsed_body["total"]
  end

  test "reserva inválida devuelve errores" do
    post "/api/v1/appointments", headers: auth, as: :json, params: {
      appointment: { stylist_id: stylists(:two).id, scheduled_at: 1.day.ago.iso8601, service_ids: [] }
    }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"].keys, "scheduled_at"
  end
end
