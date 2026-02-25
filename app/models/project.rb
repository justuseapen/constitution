class Project < ApplicationRecord
  belongs_to :team
  has_many :documents, dependent: :destroy
  has_many :blueprints, dependent: :destroy
  has_many :phases, dependent: :destroy
  has_many :work_orders, dependent: :destroy
  has_many :feedback_items, dependent: :destroy

  validates :name, presence: true

  enum :status, { active: 0, archived: 1 }, default: :active
end
