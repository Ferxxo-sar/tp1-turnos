class Stylist < ApplicationRecord
  OPENING_HOUR = 9
  CLOSING_HOUR = 19
  SLOT_MINUTES = 30

  has_many :appointments, dependent: :destroy
  has_one_attached :photo

  validates :name, presence: true
  validates :specialty, presence: true
  validate :photo_must_be_an_image

  scope :alphabetical, -> { order(:name) }

  # Horarios libres del día, en bloques de SLOT_MINUTES dentro del horario de
  # atención. Un horario está libre si entra completo un turno de `duration`
  # minutos sin superponerse con otro turno activo; `except` excluye un turno
  # (para reprogramarlo sin que se bloquee a sí mismo). Los domingos no se atiende.
  def available_slots(date, duration: SLOT_MINUTES, except: nil)
    return [] if date.sunday?

    day = date.in_time_zone
    busy = busy_ranges(day, except: except)
    closing = day.change(hour: CLOSING_HOUR)

    slot = day.change(hour: OPENING_HOUR)
    slots = []
    while slot + duration.minutes <= closing
      finish = slot + duration.minutes
      slots << slot if slot.future? && busy.none? { |range| range.begin < finish && slot < range.end }
      slot += SLOT_MINUTES.minutes
    end
    slots
  end

  # Franjas ocupadas por turnos no cancelados en el día de `time`.
  def busy_ranges(time, except: nil)
    appointments.where.not(status: "cancelled").where.not(id: except)
                .where(scheduled_at: time.all_day)
                .includes(appointment_services: :service)
                .map(&:time_range)
  end

  def initials
    name.split.first(2).map { |word| word[0] }.join.upcase
  end

  private

  def photo_must_be_an_image
    return unless photo.attached?

    errors.add(:photo, "debe ser una imagen") unless photo.content_type.to_s.start_with?("image/")
  end
end
