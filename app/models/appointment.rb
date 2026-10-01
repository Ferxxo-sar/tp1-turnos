class Appointment < ApplicationRecord
  STATUSES = %w[pending confirmed completed cancelled].freeze
  ACTIVE_STATUSES = %w[pending confirmed].freeze

  belongs_to :client
  belongs_to :stylist

  has_many :appointment_services, dependent: :destroy
  has_many :services, through: :appointment_services

  # Al reservar (web, API o back-office) se exige al menos un servicio. Queda
  # opcional a nivel modelo para poder crear turnos sueltos desde la consola.
  attr_accessor :require_services

  validates :scheduled_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :scheduled_at_cannot_be_in_the_past, if: :will_save_change_to_scheduled_at?
  validate :stylist_must_be_available
  validate :must_include_services, if: :require_services

  after_create_commit :send_confirmation_email

  scope :chronological, -> { order(:scheduled_at) }
  scope :upcoming, -> { where(scheduled_at: Time.current..).where(status: ACTIVE_STATUSES) }
  scope :past_or_closed, -> { where(scheduled_at: ...Time.current).or(where(status: %w[completed cancelled])) }
  scope :on_day, ->(date) { where(scheduled_at: date.in_time_zone.all_day) }
  scope :with_details, -> { includes(:client, :stylist, appointment_services: :service) }

  # Arma un turno nuevo con sus servicios, listo para guardar. El precio de cada
  # servicio se congela al crear el AppointmentService.
  def self.build_booking(attributes, service_ids)
    appointment = new(attributes)
    appointment.require_services = true
    Service.where(id: Array(service_ids).compact_blank).find_each do |service|
      appointment.appointment_services.build(service: service)
    end
    appointment
  end

  def self.status_label(status)
    I18n.t("appointment_statuses.#{status}")
  end

  def status_label
    self.class.status_label(status)
  end

  # Suma de los precios congelados al reservar, no de los precios actuales.
  def total
    appointment_services.sum { |item| item.price_at_booking.to_d }
  end

  def duration_minutes
    appointment_services.sum { |item| item.service.duration_minutes }
  end

  def ends_at
    scheduled_at + duration_minutes.minutes
  end

  def cancellable?
    ACTIVE_STATUSES.include?(status) && scheduled_at.future?
  end

  def cancel!
    update!(status: "cancelled")
  end

  private

  # Un mismo estilista no puede tener dos turnos activos a la misma hora.
  def stylist_must_be_available
    return if stylist_id.blank? || scheduled_at.blank? || status == "cancelled"

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

  def must_include_services
    errors.add(:services, "debe incluir al menos un servicio") if appointment_services.empty?
  end

  def send_confirmation_email
    AppointmentMailer.confirmation(self).deliver_later
  end
end
