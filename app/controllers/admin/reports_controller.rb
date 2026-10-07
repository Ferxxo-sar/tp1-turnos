module Admin
  class ReportsController < BaseController
    def show
      @report = MonthlyReport.new(selected_month)
    end

    private

    # ?month=2026-10 → 1/10/2026. Por defecto, el mes en curso.
    def selected_month
      Date.strptime(params[:month].to_s, "%Y-%m")
    rescue Date::Error
      Date.current
    end
  end
end
