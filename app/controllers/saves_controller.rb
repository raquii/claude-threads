class SavesController < ApplicationController
  before_action :set_message, only: %i[create destroy]

  def index
    @messages = Message.saved.includes(conversation: :project).order(saved_at: :desc)
  end

  def create
    return head :unprocessable_entity unless @message.saveable?

    @message.update!(saved_at: Time.current)
    render :update, formats: :turbo_stream
  end

  def destroy
    @message.update!(saved_at: nil)
    render :update, formats: :turbo_stream
  end

  private

  def set_message
    @message = Message.find(params[:message_id])
  end
end
