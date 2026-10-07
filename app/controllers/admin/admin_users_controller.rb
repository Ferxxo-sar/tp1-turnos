module Admin
  class AdminUsersController < BaseController
    before_action :set_admin_user, only: %i[edit update destroy]

    def index
      @admin_users = AdminUser.order(:name)
    end

    def new
      @admin_user = AdminUser.new
    end

    def create
      @admin_user = AdminUser.new(admin_user_params)

      if @admin_user.save
        redirect_to admin_admin_users_path, notice: "Administrador creado."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    # La contraseña solo cambia si se completa; en blanco se conserva la actual.
    def update
      if @admin_user.update(admin_user_params)
        redirect_to admin_admin_users_path, notice: "Administrador actualizado."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @admin_user == current_admin
        redirect_to admin_admin_users_path, alert: "No podés eliminar tu propio usuario."
      else
        @admin_user.destroy!
        redirect_to admin_admin_users_path, notice: "Administrador eliminado."
      end
    end

    private

    def set_admin_user
      @admin_user = AdminUser.find(params[:id])
    end

    def admin_user_params
      params.expect(admin_user: %i[name email password password_confirmation])
    end
  end
end
