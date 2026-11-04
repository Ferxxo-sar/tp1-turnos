require "test_helper"

class Api::CatalogTest < ActionDispatch::IntegrationTest
  test "servicios filtrados por categoría y por texto" do
    get "/api/v1/services", params: { category_id: categories(:one).id }
    assert_equal [ services(:one).id ], response.parsed_body.map { |s| s["id"] }

    get "/api/v1/services", params: { q: "manic" }
    assert_equal [ "Manicura" ], response.parsed_body.map { |s| s["name"] }
  end

  test "profesionales filtrados por nombre o especialidad" do
    get "/api/v1/stylists", params: { q: "color" }
    assert_equal [ stylists(:one).id ], response.parsed_body.map { |s| s["id"] }
  end

  test "un recurso inexistente devuelve 404 en JSON" do
    get "/api/v1/stylists/0"
    assert_response :not_found
    assert_equal({ "error" => "No encontrado" }, response.parsed_body)
  end

  test "un JSON mal formado devuelve 400 en JSON" do
    post "/api/v1/login", params: "{mal json", headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    assert_equal "El cuerpo de la petición no es un JSON válido", response.parsed_body["error"]
  end

  test "la disponibilidad tiene en cuenta la duración de los servicios" do
    day = business_time(4, hour: 11)
    Appointment.build_booking({ client: clients(:two), stylist: stylists(:two), scheduled_at: day }, [ services(:one).id ]).save!

    get "/api/v1/stylists/#{stylists(:two).id}/availability", params: { date: day.to_date.iso8601 }
    slots = response.parsed_body["slots"]
    assert_includes slots, "10:30"
    assert_not_includes slots, "11:00"
    assert_includes slots, "18:30"

    get "/api/v1/stylists/#{stylists(:two).id}/availability", params: { date: day.to_date.iso8601, service_ids: [ services(:two).id ] }
    body = response.parsed_body
    assert_equal 45, body["duration_minutes"]
    assert_includes body["slots"], "10:00"
    assert_not_includes body["slots"], "10:30", "10:30 + 45 min pisa el turno de las 11"
    assert_includes body["slots"], "18:00"
    assert_not_includes body["slots"], "18:30", "18:30 + 45 min termina después del cierre"
  end

  test "CORS permite el origen del front-end" do
    options "/api/v1/services", headers: {
      "Origin" => "http://localhost:5173",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "authorization"
    }
    assert_equal "http://localhost:5173", response.headers["Access-Control-Allow-Origin"]

    get "/api/v1/services", headers: { "Origin" => "http://otro-sitio.com" }
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end
end
