module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      rescue_from ActiveRecord::RecordNotFound do
        render_error "No encontrado", :not_found
      end

      rescue_from ActionController::ParameterMissing do |error|
        render_error "Falta el parámetro: #{error.param}", :bad_request
      end

      rescue_from ActionDispatch::Http::Parameters::ParseError do
        render_error "El cuerpo de la petición no es un JSON válido", :bad_request
      end

      private

      attr_reader :current_client

      def authenticate_client!
        @current_client = authenticate_with_http_token do |token, _options|
          Client.find_by(api_token: token) if token.present?
        end
        return if @current_client

        render_error "Token inválido o ausente", :unauthorized
      end

      # Todos los errores tienen `error` (mensaje general); los de validación
      # suman `errors` con los mensajes completos por campo.
      def render_error(message, status)
        render json: { error: message }, status: status
      end

      def render_errors(record)
        render json: { error: "Revisá los datos ingresados", errors: record.errors.to_hash(true) },
               status: :unprocessable_content
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def slots_json(date, duration, slots)
        { date: date.iso8601, duration_minutes: duration, slots: slots.map { |slot| slot.strftime("%H:%M") } }
      end

      def client_json(client)
        { id: client.id, name: client.name, email: client.email, phone: client.phone }
      end

      def session_json(client)
        { token: client.api_token, client: client_json(client) }
      end

      def category_json(category)
        { id: category.id, name: category.name }
      end

      def service_json(service)
        {
          id: service.id,
          name: service.name,
          description: service.description,
          duration_minutes: service.duration_minutes,
          price: service.price.to_f,
          category: category_json(service.category)
        }
      end

      def stylist_json(stylist)
        {
          id: stylist.id,
          name: stylist.name,
          specialty: stylist.specialty,
          bio: stylist.bio,
          photo_url: stylist.photo.attached? ? rails_blob_url(stylist.photo) : nil
        }
      end

      def appointment_json(appointment)
        {
          id: appointment.id,
          scheduled_at: appointment.scheduled_at.iso8601,
          ends_at: appointment.ends_at.iso8601,
          status: appointment.status,
          status_label: appointment.status_label,
          duration_minutes: appointment.duration_minutes,
          cancellable: appointment.cancellable?,
          notes: appointment.notes,
          total: appointment.total.to_f,
          stylist: { id: appointment.stylist.id, name: appointment.stylist.name },
          services: appointment.appointment_services.map do |item|
            { id: item.service.id, name: item.service.name, price_at_booking: item.price_at_booking.to_f }
          end
        }
      end
    end
  end
end
