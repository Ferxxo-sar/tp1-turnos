module Api
  module V1
    class CategoriesController < BaseController
      def index
        render json: Category.alphabetical.map { |category| category_json(category) }
      end

      def show
        category = Category.find(params[:id])
        render json: category_json(category).merge(services: category.services.alphabetical.map { |s| service_json(s) })
      end
    end
  end
end
