module Admin
  class StylistsController < BaseController
    before_action :set_stylist, only: %i[show edit update destroy]

    def index
      @stylists = Stylist.alphabetical.with_attached_photo
    end

    def show
      @upcoming = @stylist.appointments.with_details.upcoming.chronological
    end

    def new
      @stylist = Stylist.new
    end

    def create
      @stylist = Stylist.new(stylist_params)

      if @stylist.save
        redirect_to admin_stylist_path(@stylist), notice: "Profesional creado."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      @stylist.photo.purge_later if params[:remove_photo] == "1"

      if @stylist.update(stylist_params)
        redirect_to admin_stylist_path(@stylist), notice: "Profesional actualizado."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @stylist.destroy!
      redirect_to admin_stylists_path, notice: "Profesional eliminado."
    end

    private

    def set_stylist
      @stylist = Stylist.find(params[:id])
    end

    def stylist_params
      params.expect(stylist: %i[name specialty bio photo])
    end
  end
end
