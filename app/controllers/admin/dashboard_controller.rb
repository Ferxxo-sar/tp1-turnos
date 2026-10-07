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
      @report = MonthlyReport.new(Date.current)
      @previous_revenue = MonthlyReport.new(Date.current.prev_month).revenue

      upcoming = Appointment.where(scheduled_at: Date.current.beginning_of_day..(Date.current + 6).end_of_day)
                            .where.not(status: "cancelled").pluck(:scheduled_at).map(&:to_date).tally
      @next_days = (Date.current..(Date.current + 6)).index_with { |day| upcoming.fetch(day, 0) }
    end
  end
end
