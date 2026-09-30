class AppointmentsController < ApplicationController
  before_action :require_client
  before_action :set_appointment, only: %i[show cancel]

  def index
    appointments = current_client.appointments.with_details
    @upcoming = appointments.upcoming.chronological
    @history = appointments.past_or_closed.order(scheduled_at: :desc)
  end

  def show
  end

  def new
    @appointment = current_client.appointments.new(stylist_id: params[:stylist_id])
    @date = params[:date].presence || Date.current.iso8601
    @selected_time = params[:time]
    load_form_data
  end

  def create
    @appointment = Appointment.build_booking(
      booking_params.merge(client: current_client, scheduled_at: scheduled_at_param),
      params.dig(:appointment, :service_ids)
    )

    if @appointment.save
      redirect_to appointment_path(@appointment), notice: "¡Turno reservado! Te enviamos la confirmación por email."
    else
      @date = params.dig(:appointment, :date)
      @selected_time = params.dig(:appointment, :time)
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def cancel
    if @appointment.cancellable?
      @appointment.cancel!
      redirect_to appointments_path, notice: "Turno cancelado."
    else
      redirect_to appointment_path(@appointment), alert: "Este turno ya no se puede cancelar."
    end
  end

  private

  def set_appointment
    @appointment = current_client.appointments.with_details.find(params[:id])
  end

  def booking_params
    params.expect(appointment: %i[stylist_id notes])
  end

  # El formulario manda fecha y hora por separado.
  def scheduled_at_param
    date = params.dig(:appointment, :date)
    time = params.dig(:appointment, :time)
    return if date.blank? || time.blank?

    Time.zone.parse("#{date} #{time}")
  end

  def load_form_data
    @stylists = Stylist.alphabetical
    @categories = Category.alphabetical.includes(:services)
    @selected_service_ids = Array(params.dig(:appointment, :service_ids)).compact_blank.map(&:to_i)
    @slots = slots_for(@appointment.stylist, @date)
  end

  def slots_for(stylist, date)
    return [] if stylist.nil? || date.blank?

    stylist.available_slots(Date.iso8601(date))
  rescue Date::Error
    []
  end
end
