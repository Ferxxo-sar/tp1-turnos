class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_client, :client_signed_in?

  private

  def current_client
    return @current_client if defined?(@current_client)

    @current_client = Client.find_by(id: session[:client_id]) if session[:client_id]
  end

  def client_signed_in?
    current_client.present?
  end

  def require_client
    return if client_signed_in?

    session[:return_to] = request.fullpath if request.get? || request.head?
    redirect_to login_path, alert: "Ingresá con tu cuenta para continuar."
  end

  def sign_in_client(client)
    reset_session
    session[:client_id] = client.id
  end
end
