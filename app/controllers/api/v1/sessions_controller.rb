module Api
  module V1
    class SessionsController < BaseController
      before_action :authenticate_client!, only: :destroy

      def create
        client = Client.find_by(email: params[:email].to_s.strip.downcase)

        if client&.authenticate(params[:password].to_s)
          client.regenerate_api_token!
          render json: { token: client.api_token, client: { id: client.id, name: client.name, email: client.email } }
        else
          render json: { error: "Email o contraseña incorrectos" }, status: :unauthorized
        end
      end

      def destroy
        current_client.update!(api_token: nil)
        head :no_content
      end
    end
  end
end
