module Api
  module V1
    class ProfilesController < BaseController
      before_action :authenticate_client!

      def show
        render json: client_json(current_client)
      end

      def update
        if current_client.update(params.expect(client: %i[name email phone]))
          render json: client_json(current_client)
        else
          render_errors(current_client)
        end
      end

      # Exige la contraseña actual. has_secure_password ignora una contraseña
      # vacía al actualizar, por eso se valida a mano.
      def password
        attributes = params.expect(client: %i[current_password password password_confirmation])

        unless current_client.authenticate(attributes[:current_password].to_s)
          current_client.errors.add(:current_password, "es incorrecta")
          return render_errors(current_client)
        end

        if attributes[:password].blank?
          current_client.errors.add(:password, :blank)
          return render_errors(current_client)
        end

        if current_client.update(attributes.slice(:password, :password_confirmation))
          head :no_content
        else
          render_errors(current_client)
        end
      end
    end
  end
end
