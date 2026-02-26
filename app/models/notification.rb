class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :message, presence: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(20) }

  after_create_commit :broadcast_to_user

  private

  def broadcast_to_user
    ActionCable.server.broadcast("notifications_#{user_id}", {
      type: "notification",
      id: id,
      message: message,
      created_at: created_at.iso8601
    })
  end
end
