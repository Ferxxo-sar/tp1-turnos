# Métricas de un mes para el back-office. Los importes salen siempre de
# price_at_booking (precio congelado al reservar), nunca del precio actual.
class MonthlyReport
  attr_reader :month

  def initialize(month)
    @month = month.beginning_of_month
  end

  def range
    month.in_time_zone.all_month
  end

  def appointments
    Appointment.where(scheduled_at: range)
  end

  def counts_by_status
    @counts_by_status ||= begin
      counts = appointments.group(:status).count
      Appointment::STATUSES.index_with { |status| counts.fetch(status, 0) }
    end
  end

  def total_count
    counts_by_status.values.sum
  end

  def cancellation_rate
    return 0 if total_count.zero?

    (counts_by_status["cancelled"] * 100.0 / total_count).round
  end

  # Facturado: turnos realizados.
  def revenue
    @revenue ||= items_with_status("completed").sum(:price_at_booking)
  end

  # A cobrar: turnos pendientes o confirmados del mes.
  def expected_revenue
    items_with_status(Appointment::ACTIVE_STATUSES).sum(:price_at_booking)
  end

  def average_ticket
    completed = counts_by_status["completed"]
    completed.zero? ? 0 : revenue / completed
  end

  def new_clients
    Client.where(created_at: range).count
  end

  # [[Stylist, turnos activos+realizados, facturado], ...] ordenado por facturación.
  def by_stylist
    counts = appointments.where.not(status: "cancelled").group(:stylist_id).count
    revenue = items_with_status("completed").group("appointments.stylist_id").sum(:price_at_booking)

    Stylist.alphabetical.map { |stylist| [ stylist, counts.fetch(stylist.id, 0), revenue.fetch(stylist.id, 0) ] }
           .sort_by { |_, count, amount| [ -amount, -count ] }
  end

  # [[Service, veces reservado, importe], ...] los más pedidos primero.
  def top_services(limit = 8)
    scope = items_with_status(Appointment::ACTIVE_STATUSES + [ "completed" ])
    counts = scope.group(:service_id).count
    amounts = scope.group(:service_id).sum(:price_at_booking)
    services = Service.where(id: counts.keys).includes(:category).index_by(&:id)

    counts.sort_by { |_, count| -count }.first(limit).map do |service_id, count|
      [ services[service_id], count, amounts[service_id] ]
    end
  end

  # { Date => cantidad de turnos no cancelados } para cada día del mes.
  def daily_counts
    times = appointments.where.not(status: "cancelled").pluck(:scheduled_at)
    counts = times.map(&:to_date).tally
    (month..month.end_of_month).index_with { |day| counts.fetch(day, 0) }
  end

  private

  def items_with_status(status)
    AppointmentService.joins(:appointment).where(appointments: { status: status, scheduled_at: range })
  end
end
