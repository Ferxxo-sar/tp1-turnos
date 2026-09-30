module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin

    helper_method :current_admin

    private

    def current_admin
      return @current_admin if defined?(@current_admin)

      @current_admin = AdminUser.find_by(id: session[:admin_user_id]) if session[:admin_user_id]
    end

    def require_admin
      redirect_to admin_login_path, alert: "Ingresá como administrador." unless current_admin
    end
  end
end
