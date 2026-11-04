require "test_helper"

class Api::AccountTest < ActionDispatch::IntegrationTest
  def auth(client = clients(:one))
    { "Authorization" => "Bearer #{client.api_token}" }
  end

  test "registro crea el cliente y devuelve un token" do
    assert_difference "Client.count", 1 do
      post "/api/v1/register", as: :json, params: {
        client: { name: "Ana Pérez", email: "ANA@mail.com ", phone: "1144556677", password: "secreta123", password_confirmation: "secreta123" }
      }
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "ana@mail.com", body["client"]["email"]
    assert_equal body["token"], Client.find_by!(email: "ana@mail.com").api_token

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{body['token']}" }
    assert_response :success
  end

  test "registro inválido devuelve los errores por campo" do
    assert_no_difference "Client.count" do
      post "/api/v1/register", as: :json, params: {
        client: { name: "", email: clients(:one).email, password: "corta", password_confirmation: "otra" }
      }
    end
    assert_response :unprocessable_content
    body = response.parsed_body
    assert_equal "Revisá los datos ingresados", body["error"]
    assert_equal %w[email name password password_confirmation], body["errors"].keys.sort
    assert_includes body["errors"]["email"], "Email ya está en uso"
  end

  test "registro sin el objeto client es un 400" do
    post "/api/v1/register", as: :json, params: { name: "X" }
    assert_response :bad_request
    assert_equal "Falta el parámetro: client", response.parsed_body["error"]
  end

  test "perfil requiere token" do
    get "/api/v1/me"
    assert_response :unauthorized
    assert_equal "Token inválido o ausente", response.parsed_body["error"]

    get "/api/v1/me", headers: { "Authorization" => "Bearer inventado" }
    assert_response :unauthorized
  end

  test "ver y editar el perfil" do
    get "/api/v1/me", headers: auth
    assert_equal({ "id" => clients(:one).id, "name" => "Cliente Uno", "email" => "cliente1@example.com", "phone" => "1122334455" },
                 response.parsed_body)

    patch "/api/v1/me", headers: auth, as: :json, params: { client: { name: "Cliente Editado", phone: "1100000000" } }
    assert_response :success
    assert_equal "Cliente Editado", response.parsed_body["name"]
    assert_equal "1100000000", clients(:one).reload.phone
  end

  test "editar el perfil con un email inválido" do
    patch "/api/v1/me", headers: auth, as: :json, params: { client: { email: "no-es-un-email" } }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"].keys, "email"
    assert_equal "cliente1@example.com", clients(:one).reload.email
  end

  test "cambiar la contraseña" do
    patch "/api/v1/me/password", headers: auth, as: :json, params: {
      client: { current_password: "password123", password: "nueva-clave", password_confirmation: "nueva-clave" }
    }
    assert_response :no_content

    post "/api/v1/login", as: :json, params: { email: clients(:one).email, password: "nueva-clave" }
    assert_response :success
  end

  test "cambiar la contraseña exige la actual" do
    patch "/api/v1/me/password", headers: auth, as: :json, params: {
      client: { current_password: "equivocada", password: "nueva-clave", password_confirmation: "nueva-clave" }
    }
    assert_response :unprocessable_content
    assert_equal [ "Contraseña actual es incorrecta" ], response.parsed_body["errors"]["current_password"]
    assert clients(:one).reload.authenticate("password123")
  end

  test "cambiar la contraseña valida confirmación y largo" do
    patch "/api/v1/me/password", headers: auth, as: :json, params: {
      client: { current_password: "password123", password: "nueva-clave", password_confirmation: "distinta" }
    }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"].keys, "password_confirmation"

    patch "/api/v1/me/password", headers: auth, as: :json, params: {
      client: { current_password: "password123", password: "", password_confirmation: "" }
    }
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"].keys, "password"
  end

  test "logout invalida el token" do
    delete "/api/v1/logout", headers: auth
    assert_response :no_content
    assert_nil clients(:one).reload.api_token

    get "/api/v1/appointments", headers: { "Authorization" => "Bearer token-cliente-uno" }
    assert_response :unauthorized
  end
end
