class RegistrationsController < ApplicationController
  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      sign_in_client(@client)
      redirect_to new_appointment_path, notice: "¡Cuenta creada! Ya podés reservar tu turno."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def client_params
    params.expect(client: %i[name email phone password password_confirmation])
  end
end
