class MessagesController < ApplicationController
  POLL_LIMIT = 500

  def index
    @conversation = Conversation.find(params[:conversation_id])
    stream = @conversation.main_transcript.messages.stream

    if params[:after].present?
      Scanner.new.sync_conversation(@conversation)
      # A re-imported transcript has all-new ids, so appending "after" would repeat the whole history.
      @reimported = params[:generation].present? && params[:generation].to_i != @conversation.main_transcript.reload.generation
      @messages = @reimported ? Message.none : stream.where("id > ?", params[:after].to_i).order(:id).limit(POLL_LIMIT)
      @run = @conversation.latest_run
      render formats: :turbo_stream
    else
      @before = params[:before].to_i
      @messages = stream.where(id: ...@before).order(id: :desc).limit(ConversationsController::PAGE_SIZE).to_a.reverse
      @has_older = @messages.any? && stream.where(id: ...@messages.first.id).exists?
    end
  end

  def show
    @message = Message.find(params[:id])
  end

  def image
    message = Message.find(params[:id])
    expires_in 1.year, public: false
    send_data Base64.decode64(message.body), type: message.media_type, disposition: :inline
  end
end
