module Api
  module V1
    class AppointmentsController < BaseController
      before_action :authenticate_client!
      before_action :set_appointment, only: %i[show cancel]

      def index
        appointments = current_client.appointments.with_details.order(scheduled_at: :desc)
        render json: appointments.map { |appointment| appointment_json(appointment) }
      end

      def show
        render json: appointment_json(@appointment)
      end

      def create
        attributes = params.expect(appointment: %i[stylist_id scheduled_at notes])
        appointment = Appointment.build_booking(
          attributes.merge(client: current_client),
          params.dig(:appointment, :service_ids)
        )

        if appointment.save
          render json: appointment_json(appointment), status: :created
        else
          render_errors(appointment)
        end
      end

      def cancel
        if @appointment.cancellable?
          @appointment.cancel!
          render json: appointment_json(@appointment)
        else
          render json: { error: "El turno ya no se puede cancelar" }, status: :unprocessable_content
        end
      end

      private

      def set_appointment
        @appointment = current_client.appointments.with_details.find(params[:id])
      end
    end
  end
end
