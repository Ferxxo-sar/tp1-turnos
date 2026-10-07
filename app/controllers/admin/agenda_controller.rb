module Admin
  class AgendaController < BaseController
    def show
      @date = parse_date(params[:date]) || Date.current
      @all_stylists = Stylist.alphabetical
      stylists = Stylist.alphabetical.with_attached_photo
      stylists = stylists.where(id: params[:stylist_id]) if params[:stylist_id].present?
      @schedule = DaySchedule.new(@date, stylists)
      @cancelled_count = Appointment.on_day(@date).where(status: "cancelled").count
    end
  end
end
