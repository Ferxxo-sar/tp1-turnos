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
  validate :must_fit_business_hours, if: :will_save_change_to_scheduled_at?
  validate :stylist_must_be_available, if: :schedule_changed?
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

  # Un turno sin servicios igual ocupa un bloque de la agenda.
  def blocked_minutes
    [ duration_minutes, Stylist::SLOT_MINUTES ].max
  end

  def time_range
    scheduled_at...(scheduled_at + blocked_minutes.minutes)
  end

  def cancellable?
    ACTIVE_STATUSES.include?(status) && scheduled_at.future?
  end

  def cancel!
    update!(status: "cancelled")
  end

  # Mueve el turno a otro horario con el mismo profesional y servicios. Vuelve a
  # quedar pendiente porque el local tiene que confirmar el horario nuevo.
  def reschedule(new_time)
    update(scheduled_at: new_time, status: "pending")
  end

  private

  def schedule_changed?
    new_record? || will_save_change_to_scheduled_at? || will_save_change_to_stylist_id? || will_save_change_to_status?
  end

  # Un mismo estilista no puede tener dos turnos activos que se superpongan,
  # teniendo en cuenta la duración de los servicios de cada uno.
  def stylist_must_be_available
    return if stylist.blank? || scheduled_at.blank? || ACTIVE_STATUSES.exclude?(status)

    finish = scheduled_at + blocked_minutes.minutes
    conflict = stylist.busy_ranges(scheduled_at, except: id)
                      .any? { |range| range.begin < finish && scheduled_at < range.end }

    errors.add(:scheduled_at, "el estilista ya tiene un turno en ese horario") if conflict
  end

  # Lunes a sábado, dentro del horario de atención y en bloques de SLOT_MINUTES.
  def must_fit_business_hours
    return if scheduled_at.blank?

    time = scheduled_at.in_time_zone
    opening = time.change(hour: Stylist::OPENING_HOUR)
    closing = time.change(hour: Stylist::CLOSING_HOUR)

    if time.sunday?
      errors.add(:scheduled_at, "debe ser de lunes a sábado")
    elsif time < opening || time + blocked_minutes.minutes > closing
      errors.add(:scheduled_at, "debe estar dentro del horario de atención (#{Stylist::OPENING_HOUR} a #{Stylist::CLOSING_HOUR} hs)")
    elsif (time.min % Stylist::SLOT_MINUTES).nonzero? || time.sec.nonzero?
      errors.add(:scheduled_at, "debe coincidir con un bloque de #{Stylist::SLOT_MINUTES} minutos")
    end
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
