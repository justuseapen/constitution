class Phase < ApplicationRecord
  belongs_to :project
  has_many :work_orders, dependent: :nullify

  validates :name, presence: true

  default_scope { order(:position) }
end
