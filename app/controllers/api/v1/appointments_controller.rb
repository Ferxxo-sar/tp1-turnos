module Api
  module V1
    class AppointmentsController < BaseController
      before_action :authenticate_client!
      before_action :set_appointment, only: %i[show cancel reschedule availability]

      # ?scope=upcoming (próximos, del más cercano al más lejano) o
      # ?scope=history (pasados o cerrados, del más reciente al más viejo).
      def index
        appointments = current_client.appointments.with_details
        appointments = case params[:scope]
        when "upcoming" then appointments.upcoming.chronological
        when "history" then appointments.past_or_closed.order(scheduled_at: :desc)
        else appointments.order(scheduled_at: :desc)
        end
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
          render_error "El turno ya no se puede cancelar", :unprocessable_content
        end
      end

      def reschedule
        return render_error("El turno ya no se puede reprogramar", :unprocessable_content) unless @appointment.cancellable?

        if @appointment.reschedule(params.expect(appointment: [ :scheduled_at ])[:scheduled_at])
          render json: appointment_json(@appointment)
        else
          render_errors(@appointment)
        end
      end

      # Horarios a los que se puede mover el turno: mismo profesional y duración,
      # sin contar el propio turno como ocupado.
      def availability
        date = parse_date(params[:date])
        return render_error("Fecha inválida, usar formato AAAA-MM-DD", :bad_request) unless date

        duration = @appointment.blocked_minutes
        slots = @appointment.stylist.available_slots(date, duration: duration, except: @appointment.id)
        render json: slots_json(date, duration, slots)
      end

      private

      def set_appointment
        @appointment = current_client.appointments.with_details.find(params[:id])
      end
    end
  end
end
