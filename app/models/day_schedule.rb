# Grilla de la agenda de un día: filas = bloques de Stylist::SLOT_MINUTES dentro
# del horario de atención, columnas = profesionales. Calcula en qué fila arranca
# cada turno y cuántas ocupa según la duración de sus servicios.
class DaySchedule
  Entry = Struct.new(:appointment, :row, :span, :overlap, keyword_init: true)

  attr_reader :date, :stylists, :slots

  def initialize(date, stylists)
    @date = date
    @stylists = stylists.to_a
    @slots = build_slots
    @entries = build_entries
  end

  # Turnos de un profesional, con fila (1 = primer bloque) y cantidad de filas.
  def entries_for(stylist)
    @entries.fetch(stylist.id, [])
  end

  # Bloques libres de un profesional, para ofrecer "reservar acá".
  def free_rows_for(stylist)
    taken = entries_for(stylist).flat_map { |entry| (entry.row...(entry.row + entry.span)).to_a }
    (1..slots.size).to_a - taken
  end

  def appointments_count
    @entries.values.sum(&:size)
  end

  private

  def build_slots
    start = date.in_time_zone.change(hour: Stylist::OPENING_HOUR)
    finish = date.in_time_zone.change(hour: Stylist::CLOSING_HOUR)
    slots = []
    while start < finish
      slots << start
      start += Stylist::SLOT_MINUTES.minutes
    end
    slots
  end

  def build_entries
    appointments = Appointment.with_details
                              .on_day(date)
                              .where(stylist_id: stylists.map(&:id))
                              .where.not(status: "cancelled")
                              .chronological

    appointments.group_by(&:stylist_id).transform_values do |list|
      occupied = []
      list.map do |appointment|
        row = row_for(appointment.scheduled_at)
        span = [ (appointment.duration_minutes / Stylist::SLOT_MINUTES.to_f).ceil, 1 ].max
        span = [ span, slots.size - row + 1 ].min
        rows = (row...(row + span)).to_a
        overlap = rows.intersect?(occupied)
        occupied.concat(rows)
        Entry.new(appointment: appointment, row: row, span: span, overlap: overlap)
      end
    end
  end

  # Los turnos fuera del horario de atención se muestran en el primer o último bloque.
  def row_for(time)
    minutes = (time - slots.first) / 60
    (minutes / Stylist::SLOT_MINUTES).floor.clamp(0, slots.size - 1) + 1
  end
end
