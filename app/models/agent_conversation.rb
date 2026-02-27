class AgentConversation < ApplicationRecord
  belongs_to :conversable, polymorphic: true
  belongs_to :user
  has_many :messages, class_name: "AgentMessage", dependent: :destroy

  # Override dangerous attribute warning - we need a model_name column
  class << self
    def dangerous_attribute_method?(name)
      return false if name == "model_name"
      super
    end
  end

  validates :model_provider, presence: true
  validates :model_name, presence: true
end
