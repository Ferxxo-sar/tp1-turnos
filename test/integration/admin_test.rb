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
      new_admin_appointment_path, edit_admin_appointment_path(appointments(:one)),
      admin_agenda_path, admin_reports_path, admin_admin_users_path, new_admin_client_path,
      edit_admin_client_path(clients(:one)), new_admin_admin_user_path,
      edit_admin_admin_user_path(admin_users(:two)) ].each do |path|
      get path
      assert_response :success, "falló #{path}"
    end
  end

  test "la agenda muestra los turnos del día en la grilla" do
    appointment = appointments(:one)

    get admin_agenda_path(date: appointment.scheduled_at.to_date.iso8601)
    assert_response :success
    assert_select "a.appt-block[href=?]", admin_appointment_path(appointment), text: /#{appointment.client.name}/
  end

  test "la agenda tolera fechas inválidas y filtra por profesional" do
    get admin_agenda_path(date: "no-es-fecha", stylist_id: stylists(:one).id)
    assert_response :success
    assert_select ".agenda .head", count: 2 # esquina + un profesional
  end

  test "nuevo turno precarga profesional y horario desde la agenda" do
    get new_admin_appointment_path(stylist_id: stylists(:two).id, at: "2030-05-06T11:30")
    assert_response :success
    assert_select "select#appointment_stylist_id option[selected][value=?]", stylists(:two).id.to_s
    assert_select "input#appointment_scheduled_at[value^=?]", "2030-05-06T11:30"
  end

  test "filtros de turnos por cliente y rango de fechas" do
    get admin_appointments_path(q: clients(:two).name, from: Date.current.iso8601, to: 5.days.from_now.to_date.iso8601)
    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody", text: /#{clients(:two).name}/
  end

  test "exporta turnos a CSV" do
    get admin_appointments_path(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
    lines = response.body.delete_prefix("﻿").lines
    assert_match(/\AID;Fecha;Hora;Cliente/, lines.first)
    assert_equal Appointment.count + 1, lines.size
  end

  test "reporte mensual con mes elegido" do
    appointment = appointments(:two)
    appointment.update_columns(status: "completed")

    get admin_reports_path(month: appointment.scheduled_at.strftime("%Y-%m"))
    assert_response :success
    facturado = ActiveSupport::NumberHelper.number_to_currency(appointment.total, precision: 0, locale: :es)
    assert_select ".stat.accent .value", text: facturado

    get admin_reports_path(month: "basura")
    assert_response :success
  end

  test "ABM de clientes desde el back-office" do
    assert_difference "Client.count", 1 do
      post admin_clients_path, params: { client: { name: "Mostrador", email: "mostrador@example.com", phone: "123" } }
    end
    client = Client.find_by!(email: "mostrador@example.com")
    assert client.password_digest.present?, "se genera una contraseña si no se carga"
    assert_redirected_to admin_client_path(client)

    patch admin_client_path(client), params: { client: { phone: "999", password: "" } }
    assert_equal "999", client.reload.phone

    delete admin_client_path(client)
    assert_not Client.exists?(client.id)
  end

  test "no se elimina un cliente con turnos próximos" do
    assert_no_difference "Client.count" do
      delete admin_client_path(clients(:one))
    end
    assert_redirected_to admin_client_path(clients(:one))
  end

  test "ABM de administradores" do
    post admin_admin_users_path, params: { admin_user: { name: "Recepción", email: "recepcion@example.com",
                                                         password: "clave1234", password_confirmation: "clave1234" } }
    admin = AdminUser.find_by!(email: "recepcion@example.com")

    patch admin_admin_user_path(admin), params: { admin_user: { name: "Recepción PM", password: "", password_confirmation: "" } }
    assert_equal "Recepción PM", admin.reload.name
    assert admin.authenticate("clave1234"), "la contraseña vacía conserva la actual"

    delete admin_admin_user_path(admin)
    assert_not AdminUser.exists?(admin.id)
  end

  test "un administrador no puede eliminarse a sí mismo" do
    assert_no_difference "AdminUser.count" do
      delete admin_admin_user_path(admin_users(:one))
    end
  end

  test "contraseña de administrador demasiado corta" do
    assert_no_difference "AdminUser.count" do
      post admin_admin_users_path, params: { admin_user: { name: "X", email: "x@example.com", password: "123", password_confirmation: "123" } }
    end
    assert_response :unprocessable_content
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
