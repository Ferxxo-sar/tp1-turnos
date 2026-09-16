class Service < ApplicationRecord
  belongs_to :category

  has_many :appointment_services, dependent: :restrict_with_error
  has_many :appointments, through: :appointment_services

  validates :name, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
end
