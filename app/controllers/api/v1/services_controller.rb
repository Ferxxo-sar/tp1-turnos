module Api
  module V1
    class ServicesController < BaseController
      def index
        services = Service.includes(:category).alphabetical
        services = services.where(category_id: params[:category_id]) if params[:category_id].present?
        render json: services.map { |service| service_json(service) }
      end

      def show
        render json: service_json(Service.find(params[:id]))
      end
    end
  end
end
