class NotesController < ApplicationController
  def index
    @notes_by_conversation = Note.includes(conversation: :project)
      .order(Arel.sql("message_uuid IS NOT NULL"), :created_at)
      .group_by(&:conversation)
      .sort_by { |conversation, _| -(conversation.last_activity_at || Time.at(0)).to_f }
  end

  # Saves the conversation's note, or a message's note when message_uuid is given; a blank body deletes it.
  def update
    @conversation = Conversation.find(params[:conversation_id])
    attributes = params.expect(note: %i[body message_uuid])
    note = @conversation.notes.find_or_initialize_by(message_uuid: attributes[:message_uuid].presence)
    if attributes[:body].present?
      note.update!(body: attributes[:body])
    elsif note.persisted?
      note.destroy!
    end

    render turbo_stream: [
      turbo_stream.update("notes_panel_body", partial: "notes/panel", locals: { conversation: @conversation }),
      turbo_stream.update("notes_toggle_count", @conversation.notes.count.to_s),
      turbo_stream.update("notes_count", Note.count.to_s)
    ]
  end

  def preview
    conversation = Conversation.find(params[:conversation_id])
    render html: helpers.markdown(params[:body].to_s, cwd: conversation.cwd)
  end
end
