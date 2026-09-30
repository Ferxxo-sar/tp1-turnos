module Admin
  class DashboardController < BaseController
    def index
      @today = Appointment.with_details.on_day(Date.current).where.not(status: "cancelled").chronological
      @pending = Appointment.with_details.upcoming.where(status: "pending").chronological.limit(8)
      @stats = {
        today: @today.size,
        pending: Appointment.upcoming.where(status: "pending").count,
        week: Appointment.where(scheduled_at: Time.current.all_week).where.not(status: "cancelled").count,
        clients: Client.count
      }
      @month_revenue = AppointmentService.joins(:appointment)
                                         .where(appointments: { status: "completed", scheduled_at: Time.current.all_month })
                                         .sum(:price_at_booking)
    end
  end
end
