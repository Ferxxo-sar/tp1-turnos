module Admin
  class AppointmentsController < BaseController
    before_action :set_appointment, only: %i[show edit update destroy]

    def index
      @appointments = Appointment.with_details.order(scheduled_at: :desc)
      @appointments = @appointments.where(status: params[:status]) if Appointment::STATUSES.include?(params[:status])
      @appointments = @appointments.where(stylist_id: params[:stylist_id]) if params[:stylist_id].present?
      @appointments = @appointments.on_day(Date.iso8601(params[:date])) if params[:date].present?
      @stylists = Stylist.alphabetical
    rescue Date::Error
      redirect_to admin_appointments_path, alert: "Fecha inválida."
    end

    def show
    end

    def new
      @appointment = Appointment.new(scheduled_at: 1.day.from_now.change(hour: 10), status: "confirmed")
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

    def set_appointment
      @appointment = Appointment.with_details.find(params[:id])
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
