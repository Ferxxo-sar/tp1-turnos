module Api
  module V1
    class SessionsController < BaseController
      before_action :authenticate_client!, only: :destroy

      def create
        client = Client.find_by(email: params[:email].to_s.strip.downcase)

        if client&.authenticate(params[:password].to_s)
          client.regenerate_api_token!
          render json: session_json(client)
        else
          render_error "Email o contraseña incorrectos", :unauthorized
        end
      end

      def destroy
        current_client.update!(api_token: nil)
        head :no_content
      end
    end
  end
end
