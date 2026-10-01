class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to login_path, alert: "Demasiados intentos. Probá de nuevo en unos minutos." }

  def new
    redirect_to appointments_path if client_signed_in?
  end

  def create
    client = Client.find_by(email: params[:email].to_s.strip.downcase)

    if client&.authenticate(params[:password].to_s)
      return_to = session[:return_to]
      sign_in_client(client)
      redirect_to return_to || appointments_path, notice: "¡Hola, #{client.name}!"
    else
      flash.now[:alert] = "Email o contraseña incorrectos."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Cerraste sesión."
  end
end
