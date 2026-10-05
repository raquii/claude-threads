class FavoritesController < ApplicationController
  before_action :set_conversation

  def create
    @conversation.update!(favorited_at: Time.current)
    render :update, formats: :turbo_stream
  end

  def destroy
    @conversation.update!(favorited_at: nil)
    render :update, formats: :turbo_stream
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
    @current_id = params[:current].to_i
  end
end
