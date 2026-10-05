class Transcript < ApplicationRecord
  INSERT_BATCH = 500

  belongs_to :conversation
  has_many :messages, dependent: :delete_all

  def subagent?
    agent_id.present?
  end

  # Reads only the complete lines appended since the last ingest; a shrunken file is re-read from the start.
  # Polls, scans, and runs all ingest the same file, so the offset is re-read inside SQLite's immediate
  # transaction: a second caller waits for the first and then sees nothing new to insert.
  def ingest!
    transaction do
      reload
      size = File.size(path)
      restart! if size < byte_offset
      next if size == byte_offset

      chunk = File.open(path, "rb") do |file|
        file.seek(byte_offset)
        file.read
      end
      last_newline = chunk.rindex("\n")
      next if last_newline.nil?

      complete = chunk.byteslice(0, last_newline + 1)
      rows = []
      metadata = {}
      complete.force_encoding(Encoding::UTF_8).each_line do |line|
        data = JSON.parse(line) rescue next
        parsed = TranscriptLine.new(data)
        rows.concat(parsed.rows)
        metadata[:first_cwd] ||= parsed.metadata[:cwd]
        metadata.merge!(parsed.metadata.compact)
      end

      last_id = messages.maximum(:id) || 0
      rows.each_slice(INSERT_BATCH) do |slice|
        Message.insert_all!(slice.map { |row| row.merge(conversation_id: conversation_id, transcript_id: id) })
      end
      new_rows = messages.where(id: (last_id + 1)..)
      Message.index_for_search(new_rows)
      update!(byte_offset: byte_offset + complete.bytesize, file_size: size, file_mtime: File.mtime(path),
        carried_saves: reattach_saves(new_rows))
      conversation.absorb!(metadata, rows, from_subagent: subagent?)
    end
  end

  private

  # Saved rows are parked in carried_saves until their lines are read again, which may take several ingests
  # when the rewritten file is caught mid-write. The generation bump tells open pages to reload.
  def restart!
    parked = Array(carried_saves) + messages.saved.pluck(:uuid, :kind, :saved_at).map { |uuid, kind, at| [ uuid, kind, at.iso8601(6) ] }
    Message.unindex_for_search(messages)
    messages.delete_all
    update!(byte_offset: 0, generation: generation + 1, carried_saves: parked.presence)
    return if subagent?

    conversation.update!(
      message_count: conversation.messages.where(kind: Message::TALLIED_KINDS, sidechain: false).count,
      first_prompt: nil, ai_title: nil, agent_name: nil
    )
  end

  def reattach_saves(new_rows)
    Array(carried_saves).reject do |uuid, kind, saved_at|
      new_rows.where(uuid: uuid, kind: kind).update_all(saved_at: Time.iso8601(saved_at)).positive?
    end.presence
  end
end
