class TranscriptsController < ApplicationController
  LIMIT = 400

  def show
    @transcript = Transcript.find(params[:id])
    @messages = @transcript.messages.stream.order(:id).limit(LIMIT)
  end
end
