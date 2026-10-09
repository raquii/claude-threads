# A note with no message_uuid is the conversation's own note; the rest are attached to a message
# by its line uuid, which survives re-imports where message ids do not.
class Note < ApplicationRecord
  belongs_to :conversation

  validates :body, presence: true
  validates :message_uuid, uniqueness: { scope: :conversation_id }

  scope :on_conversation, -> { where(message_uuid: nil) }
  scope :on_messages, -> { where.not(message_uuid: nil) }

  def message
    return if message_uuid.nil?

    @message ||= conversation.messages.where(uuid: message_uuid, kind: Message::TALLIED_KINDS, sidechain: false).order(:id).first
  end
end
