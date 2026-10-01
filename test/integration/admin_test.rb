require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  setup do
    post admin_login_path, params: { email: admin_users(:one).email, password: "password123" }
  end

  test "el back-office requiere login de administrador" do
    delete admin_logout_path
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "un cliente logueado no accede al back-office" do
    delete admin_logout_path
    post login_path, params: { email: clients(:one).email, password: "password123" }
    get admin_appointments_path
    assert_redirected_to admin_login_path
  end

  test "dashboard y listados" do
    [ admin_root_path, admin_appointments_path, admin_stylists_path, admin_services_path,
      admin_categories_path, admin_clients_path, admin_client_path(clients(:one)),
      admin_stylist_path(stylists(:one)), admin_appointment_path(appointments(:one)),
      new_admin_appointment_path, edit_admin_appointment_path(appointments(:one)) ].each do |path|
      get path
      assert_response :success, "falló #{path}"
    end
  end

  test "CRUD de categorías" do
    post admin_categories_path, params: { category: { name: "Piel" } }
    category = Category.find_by!(name: "Piel")
    patch admin_category_path(category), params: { category: { name: "Rostro" } }
    assert_equal "Rostro", category.reload.name
    delete admin_category_path(category)
    assert_not Category.exists?(category.id)
  end

  test "no se elimina una categoría con servicios" do
    assert_no_difference "Category.count" do
      delete admin_category_path(categories(:one))
    end
    assert_redirected_to admin_categories_path
  end

  test "crear servicio" do
    assert_difference "Service.count", 1 do
      post admin_services_path, params: { service: { category_id: categories(:one).id, name: "Peinado", duration_minutes: 40, price: 5000 } }
    end
  end

  test "crear profesional con foto" do
    photo = Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")
    post admin_stylists_path, params: { stylist: { name: "Nueva", specialty: "Cortes", photo: photo } }
    assert Stylist.find_by!(name: "Nueva").photo.attached?
  end

  test "crear turno y cambiar su estado" do
    time = 4.days.from_now.change(hour: 12)
    post admin_appointments_path, params: { appointment: {
      client_id: clients(:one).id, stylist_id: stylists(:two).id, scheduled_at: time,
      status: "confirmed", service_ids: [ services(:two).id ]
    } }
    appointment = Appointment.last
    assert_redirected_to admin_appointment_path(appointment)

    patch admin_appointment_path(appointment), params: { appointment: { status: "completed" } }
    assert_equal "completed", appointment.reload.status
  end

  test "se puede completar un turno cuya hora ya pasó" do
    appointment = appointments(:one)
    appointment.update_column(:scheduled_at, 2.hours.ago)
    patch admin_appointment_path(appointment), params: { appointment: { status: "completed" } }
    assert_equal "completed", appointment.reload.status
  end
end
