# Datos de prueba. Es idempotente: se puede correr varias veces con bin/rails db:seed.

puts "Cargando datos de prueba..."

admin = AdminUser.find_or_initialize_by(email: "admin@turnos.test")
admin.update!(name: "Administración", password: "admin1234")

catalog = {
  "Cabello" => [
    [ "Corte", "Corte y peinado.", 30, 8500 ],
    [ "Color", "Coloración completa.", 90, 24000 ],
    [ "Brushing", "Lavado y brushing.", 30, 6000 ]
  ],
  "Uñas" => [
    [ "Manicura", "Manicura tradicional.", 45, 7000 ],
    [ "Esmaltado semipermanente", "Incluye retiro del anterior.", 60, 9500 ]
  ],
  "Piel" => [
    [ "Limpieza facial", "Limpieza profunda con extracción.", 60, 15000 ]
  ]
}

catalog.each do |category_name, services|
  category = Category.find_or_create_by!(name: category_name)
  services.each do |name, description, minutes, price|
    service = category.services.find_or_initialize_by(name: name)
    service.update!(description: description, duration_minutes: minutes, price: price)
  end
end

stylists = [
  [ "Ana Pérez", "Colorista", "Más de 10 años trabajando con color, mechas y balayage." ],
  [ "Martín Gómez", "Cortes", "Cortes clásicos y modernos para todo tipo de cabello." ],
  [ "Lucía Fernández", "Manicura y estética", "Manicura, semipermanente y tratamientos faciales." ]
].map do |name, specialty, bio|
  stylist = Stylist.find_or_initialize_by(name: name)
  stylist.update!(specialty: specialty, bio: bio)
  stylist
end

clients = [
  [ "Juan López", "juan@mail.com", "1122334455" ],
  [ "María Díaz", "maria@mail.com", "1155667788" ],
  [ "Sofía Ruiz", "sofia@mail.com", "1144556677" ],
  [ "Martín Cruz", "martin@mail.com", "1133221100" ],
  [ "Valentina Sosa", "valen@mail.com", "1166778899" ],
  [ "Diego Romero", "diego@mail.com", nil ]
].map do |name, email, phone|
  client = Client.find_or_initialize_by(email: email)
  client.update!(name: name, phone: phone, password: "cliente123")
  client
end

if Appointment.none?
  base = Date.current.next_weekday
  services = Service.all.index_by(&:name)

  [
    [ clients[0], stylists[1], base, 10, [ "Corte" ], "confirmed" ],
    [ clients[0], stylists[0], base + 2, 15, [ "Color", "Brushing" ], "pending" ],
    [ clients[1], stylists[2], base, 11, [ "Manicura" ], "pending" ],
    [ clients[1], stylists[2], base + 1, 16, [ "Limpieza facial" ], "confirmed" ]
  ].each do |client, stylist, date, hour, service_names, status|
    date += 1 if date.sunday?
    appointment = Appointment.build_booking(
      { client: client, stylist: stylist, scheduled_at: date.in_time_zone.change(hour: hour), status: status },
      services.values_at(*service_names).map(&:id)
    )
    appointment.save!
  end

  # Historial del mes y del anterior, para que el dashboard y los reportes
  # tengan datos. Un turno no se puede crear en el pasado, así que se crea a
  # futuro y después se mueve la fecha sin validar.
  history = Random.new(42)
  first_day = Date.current.prev_month.beginning_of_month
  (first_day...Date.current).each do |date|
    next if date.sunday?

    history.rand(1..3).times do
      appointment = Appointment.build_booking(
        { client: clients.sample(random: history), stylist: stylists.sample(random: history),
          scheduled_at: 1.year.from_now.change(hour: history.rand(9..18)), status: "pending" },
        services.values.sample(history.rand(1..2), random: history).map(&:id)
      )
      next unless appointment.save

      appointment.update_columns(
        scheduled_at: date.in_time_zone.change(hour: history.rand(9..18), min: [ 0, 30 ].sample(random: history)),
        status: history.rand < 0.85 ? "completed" : "cancelled"
      )
    end
  end

  # Agenda de la próxima semana.
  (Date.current..(Date.current + 6)).each do |date|
    next if date.sunday?

    history.rand(3..6).times do
      time = date.in_time_zone.change(hour: history.rand(9..18), min: [ 0, 30 ].sample(random: history))
      next if time.past?

      Appointment.build_booking(
        { client: clients.sample(random: history), stylist: stylists.sample(random: history),
          scheduled_at: time, status: history.rand < 0.6 ? "confirmed" : "pending" },
        services.values.sample(history.rand(1..2), random: history).map(&:id)
      ).save
    end
  end
end

puts "Listo."
puts "  Admin:   admin@turnos.test / admin1234   → /admin"
puts "  Cliente: juan@mail.com / cliente123      → /ingresar"
