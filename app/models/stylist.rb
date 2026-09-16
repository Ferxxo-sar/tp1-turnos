class Stylist < ApplicationRecord
  has_many :appointments, dependent: :destroy
  has_one_attached :photo

  validates :name, presence: true
  validates :specialty, presence: true
end
