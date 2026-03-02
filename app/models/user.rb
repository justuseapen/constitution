class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :team, optional: true
  has_many :notifications, dependent: :destroy

  validates :name, presence: true

  enum :role, { member: 0, admin: 1, owner: 2 }, default: :member
end
