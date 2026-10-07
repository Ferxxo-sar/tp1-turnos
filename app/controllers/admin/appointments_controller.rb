module Admin
  class AppointmentsController < BaseController
    before_action :set_appointment, only: %i[show edit update destroy]

    def index
      scope = filtered_appointments

      respond_to do |format|
        format.html do
          @total_amount = AppointmentService.where(appointment_id: scope.where.not(status: "cancelled").select(:id)).sum(:price_at_booking)
          @appointments = paginate(scope.with_details.order(scheduled_at: :desc))
          @stylists = Stylist.alphabetical
        end
        format.csv do
          send_data AppointmentsCsv.new(scope.with_details.order(:scheduled_at)).to_s,
                    filename: "turnos-#{Date.current.iso8601}.csv", type: "text/csv; charset=utf-8"
        end
      end
    end

    def show
    end

    def new
      @appointment = Appointment.new(
        client_id: params[:client_id],
        stylist_id: params[:stylist_id],
        scheduled_at: requested_time || 1.day.from_now.change(hour: 10),
        status: "confirmed"
      )
      load_form_data
    end

    def create
      @appointment = Appointment.build_booking(appointment_params, params.dig(:appointment, :service_ids))

      if @appointment.save
        redirect_to admin_appointment_path(@appointment), notice: "Turno creado."
      else
        load_form_data
        render :new, status: :unprocessable_content
      end
    end

    def edit
      load_form_data
    end

    def update
      if @appointment.update(appointment_params)
        redirect_back_or_to admin_appointment_path(@appointment), notice: "Turno actualizado."
      else
        load_form_data
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @appointment.destroy!
      redirect_to admin_appointments_path, notice: "Turno eliminado."
    end

    private

    def filtered_appointments
      scope = Appointment.all
      scope = scope.where(status: params[:status]) if Appointment::STATUSES.include?(params[:status])
      scope = scope.where(stylist_id: params[:stylist_id]) if params[:stylist_id].present?

      if (day = parse_date(params[:date]))
        scope = scope.on_day(day)
      else
        from = parse_date(params[:from])
        to = parse_date(params[:to])
        scope = scope.where(scheduled_at: from.beginning_of_day..) if from
        scope = scope.where(scheduled_at: ..to.end_of_day) if to
      end

      if params[:q].present?
        query = "%#{Client.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.where(client_id: Client.where("name LIKE :q OR email LIKE :q OR phone LIKE :q", q: query).select(:id))
      end

      scope
    end

    def set_appointment
      @appointment = Appointment.with_details.find(params[:id])
    end

    # La agenda arma links a "nuevo turno" con ?at=2026-10-08T10:30 para precargar el horario.
    def requested_time
      Time.zone.iso8601(params[:at].to_s) if params[:at].present?
    rescue ArgumentError
      nil
    end

    def appointment_params
      params.expect(appointment: %i[client_id stylist_id scheduled_at status notes])
    end

    def load_form_data
      @clients = Client.order(:name)
      @stylists = Stylist.alphabetical
      @categories = Category.alphabetical.includes(:services)
      @selected_service_ids = Array(params.dig(:appointment, :service_ids)).compact_blank.map(&:to_i)
    end
  end
end
