class AgentConversation < ApplicationRecord
  belongs_to :conversable, polymorphic: true
  belongs_to :user
  has_many :messages, class_name: "AgentMessage", dependent: :destroy

  validates :model_provider, presence: true
  validates :model_name, presence: true
end
