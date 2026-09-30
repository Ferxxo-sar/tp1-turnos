module Admin
  class ServicesController < BaseController
    before_action :set_service, only: %i[edit update destroy]
    before_action :load_categories, only: %i[new create edit update]

    def index
      @services = Service.includes(:category).order("categories.name", :name).references(:category)
    end

    def new
      @service = Service.new(duration_minutes: 30)
    end

    def create
      @service = Service.new(service_params)

      if @service.save
        redirect_to admin_services_path, notice: "Servicio creado."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @service.update(service_params)
        redirect_to admin_services_path, notice: "Servicio actualizado."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @service.destroy
        redirect_to admin_services_path, notice: "Servicio eliminado."
      else
        redirect_to admin_services_path, alert: @service.errors.full_messages.to_sentence
      end
    end

    private

    def set_service
      @service = Service.find(params[:id])
    end

    def load_categories
      @categories = Category.alphabetical
    end

    def service_params
      params.expect(service: %i[category_id name description duration_minutes price])
    end
  end
end
