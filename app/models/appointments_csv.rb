require "csv"

# Exporta un listado de turnos a CSV. Usa ";" como separador y BOM UTF-8 para
# que Excel configurado en español lo abra con columnas y acentos correctos.
class AppointmentsCsv
  HEADERS = [ "ID", "Fecha", "Hora", "Cliente", "Email", "Teléfono", "Profesional", "Servicios", "Duración (min)", "Total", "Estado", "Notas" ].freeze

  def initialize(appointments)
    @appointments = appointments
  end

  def to_s
    "﻿" + CSV.generate(col_sep: ";") do |csv|
      csv << HEADERS
      @appointments.each { |appointment| csv << row(appointment) }
    end
  end

  private

  def row(appointment)
    [
      appointment.id,
      appointment.scheduled_at.strftime("%d/%m/%Y"),
      appointment.scheduled_at.strftime("%H:%M"),
      appointment.client.name,
      appointment.client.email,
      appointment.client.phone,
      appointment.stylist.name,
      appointment.appointment_services.map { |item| item.service.name }.join(", "),
      appointment.duration_minutes,
      format("%.2f", appointment.total).tr(".", ","),
      appointment.status_label,
      appointment.notes
    ]
  end
end
