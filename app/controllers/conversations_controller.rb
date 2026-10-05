class ConversationsController < ApplicationController
  PAGE_SIZE = 60

  before_action :set_conversation, only: %i[show update]

  def index
    conversation = Conversation.active.recent_first.first
    redirect_to conversation if conversation
  end

  # With ?at=, the page opens on that message; the poller then fills in everything after it.
  def show
    stream = @conversation.main_transcript.messages.stream
    @target_id = params[:at].to_i if params[:at].present?
    @messages =
      if @target_id
        before = stream.where(id: ...@target_id).order(id: :desc).limit(PAGE_SIZE / 2).to_a.reverse
        before + stream.where(id: @target_id..).order(:id).limit(PAGE_SIZE / 2).to_a
      else
        stream.order(id: :desc).limit(PAGE_SIZE).to_a.reverse
      end
    @has_older = @messages.any? && stream.where(id: ...@messages.first.id).exists?
    @run = @conversation.runs.order(:id).last
  end

  def update
    @conversation.update!(conversation_params)
    redirect_to @conversation
  end

  def sidebar
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def conversation_params
    permitted = params.expect(conversation: %i[custom_name archived])
    archived = permitted.delete(:archived)
    permitted[:archived_at] = ActiveModel::Type::Boolean.new.cast(archived) ? Time.current : nil unless archived.nil?
    permitted
  end
end
