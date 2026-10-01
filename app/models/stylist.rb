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
  # atención. Los domingos no se atiende.
  def available_slots(date)
    return [] if date.sunday?

    day = date.in_time_zone
    taken = appointments.where.not(status: "cancelled").where(scheduled_at: day.all_day).pluck(:scheduled_at)

    slot = day.change(hour: OPENING_HOUR)
    closing = day.change(hour: CLOSING_HOUR)
    slots = []
    while slot < closing
      slots << slot if slot.future? && taken.none? { |time| time == slot }
      slot += SLOT_MINUTES.minutes
    end
    slots
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
