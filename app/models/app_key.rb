class AppKey < ApplicationRecord
  belongs_to :project
  validates :name, presence: true
  validates :token, presence: true, uniqueness: true
  before_validation :generate_token, on: :create

  scope :active, -> { where(active: true) }

  private

  def generate_token
    self.token ||= "sf-int-#{SecureRandom.hex(12)}"
  end
end
