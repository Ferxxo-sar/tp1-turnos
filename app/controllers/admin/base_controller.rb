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

    # Paginación mínima por offset. Deja @pagination para el partial admin/shared/pagination.
    def paginate(scope, per: 20)
      total = scope.count
      pages = [ (total / per.to_f).ceil, 1 ].max
      page = params[:page].to_i.clamp(1, pages)
      @pagination = { page: page, pages: pages, total: total }
      scope.limit(per).offset((page - 1) * per)
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
