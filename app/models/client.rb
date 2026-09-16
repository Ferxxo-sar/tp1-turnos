class Client < ApplicationRecord
  has_secure_password

  has_many :appointments, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :api_token, uniqueness: true, allow_nil: true

  def regenerate_api_token!
    update!(api_token: SecureRandom.hex(24))
  end
end
