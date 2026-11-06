module Api
  module V1
    class RegistrationsController < BaseController
      def create
        client = Client.new(params.expect(client: %i[name email phone password password_confirmation]))

        if client.save
          client.regenerate_api_token!
          render json: session_json(client), status: :created
        else
          render_errors(client)
        end
      end
    end
  end
end
