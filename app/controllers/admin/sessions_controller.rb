module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin
    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to admin_login_path, alert: "Demasiados intentos. Probá de nuevo en unos minutos." }

    def new
      redirect_to admin_root_path if current_admin
    end

    def create
      admin = AdminUser.find_by(email: params[:email].to_s.strip.downcase)

      if admin&.authenticate(params[:password].to_s)
        reset_session
        session[:admin_user_id] = admin.id
        redirect_to admin_root_path, notice: "Bienvenido/a, #{admin.name}."
      else
        flash.now[:alert] = "Email o contraseña incorrectos."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      reset_session
      redirect_to admin_login_path, notice: "Sesión cerrada."
    end
  end
end
