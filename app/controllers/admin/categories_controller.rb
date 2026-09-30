module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]

    def index
      @categories = Category.alphabetical.includes(:services)
    end

    def new
      @category = Category.new
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        redirect_to admin_categories_path, notice: "Categoría creada."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to admin_categories_path, notice: "Categoría actualizada."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @category.destroy
        redirect_to admin_categories_path, notice: "Categoría eliminada."
      else
        redirect_to admin_categories_path, alert: @category.errors.full_messages.to_sentence
      end
    end

    private

    def set_category
      @category = Category.find(params[:id])
    end

    def category_params
      params.expect(category: [ :name ])
    end
  end
end
