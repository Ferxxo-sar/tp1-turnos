class Appointment < ApplicationRecord
  STATUSES = %w[pending confirmed completed cancelled].freeze

  belongs_to :client
  belongs_to :stylist

  has_many :appointment_services, dependent: :destroy
  has_many :services, through: :appointment_services

  validates :scheduled_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :scheduled_at_cannot_be_in_the_past
  validate :stylist_must_be_available

  private

  # Un mismo estilista no puede tener dos turnos activos a la misma hora.
  def stylist_must_be_available
    return if stylist_id.blank? || scheduled_at.blank?

    conflict = Appointment.where(stylist_id: stylist_id, scheduled_at: scheduled_at)
                           .where.not(id: id)
                           .where.not(status: "cancelled")
                           .exists?

    errors.add(:scheduled_at, "el estilista ya tiene un turno en ese horario") if conflict
  end

  def scheduled_at_cannot_be_in_the_past
    return if scheduled_at.blank?

    errors.add(:scheduled_at, "no puede ser en el pasado") if scheduled_at < Time.current
  end
end
