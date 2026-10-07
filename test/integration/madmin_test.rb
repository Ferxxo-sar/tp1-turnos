require "test_helper"

class MadminTest < ActionDispatch::IntegrationTest
  test "el panel de base de datos exige login de administrador" do
    get madmin_root_path
    assert_redirected_to admin_login_path

    get madmin_clients_path
    assert_redirected_to admin_login_path
  end

  test "un cliente logueado no entra al panel" do
    post login_path, params: { email: clients(:one).email, password: "password123" }
    get madmin_clients_path
    assert_redirected_to admin_login_path
  end

  test "un administrador ve los modelos y no ve el token de los clientes" do
    post admin_login_path, params: { email: admin_users(:one).email, password: "password123" }

    [ madmin_root_path, madmin_clients_path, madmin_client_path(clients(:one)), madmin_appointments_path,
      madmin_appointment_path(appointments(:one)), madmin_services_path, madmin_stylists_path,
      madmin_categories_path, madmin_admin_users_path ].each do |path|
      get path
      assert_response :success, "falló #{path}"
      assert_no_match clients(:one).api_token, response.body
    end

    get madmin_appointments_path
    assert_select "td", text: /#{clients(:one).name}/
    assert_select "a", text: "Servicios de turnos"
  end
end
