class AdminUser < ApplicationRecord
  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP }
end
