class AppointmentMailer < ApplicationMailer
  def confirmation(appointment)
    @appointment = appointment
    @client = appointment.client
    @business_name = Rails.configuration.x.business_name

    mail to: @client.email, subject: "#{@business_name}: turno reservado para el #{I18n.l(appointment.scheduled_at, format: :short)}"
  end
end
