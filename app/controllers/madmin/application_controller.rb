module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_admin_user

    # Usa la misma sesión que el back-office (/admin): solo entran AdminUser.
    def authenticate_admin_user
      return if session[:admin_user_id] && AdminUser.exists?(session[:admin_user_id])

      redirect_to main_app.admin_login_path, alert: "Ingresá como administrador."
    end
  end
end
