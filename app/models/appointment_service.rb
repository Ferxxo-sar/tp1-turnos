class AppointmentService < ApplicationRecord
  belongs_to :appointment
  belongs_to :service

  validates :price_at_booking, numericality: { greater_than_or_equal_to: 0 }
  validates :service_id, uniqueness: { scope: :appointment_id, message: "ya fue agregado a este turno" }

  before_validation :set_price_at_booking, on: :create

  private

  # Congela el precio del servicio al momento de la reserva.
  def set_price_at_booking
    self.price_at_booking ||= service&.price
  end
end
