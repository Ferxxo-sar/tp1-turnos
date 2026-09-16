class Category < ApplicationRecord
  has_many :services, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
