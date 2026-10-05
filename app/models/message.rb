class Message < ApplicationRecord
  KINDS = %w[prompt text thinking tool_use tool_result image meta command marker summary].freeze
  TALLIED_KINDS = %w[prompt text].freeze
  SEARCHABLE_KINDS = %w[prompt text].freeze
  MARK_START = "\u0002"
  MARK_END = "\u0003"

  belongs_to :conversation
  belongs_to :transcript

  scope :stream, -> { where.not(kind: "tool_result").where("kind != 'image' OR tool_use_id IS NULL") }
  scope :saved, -> { where.not(saved_at: nil) }

  # Rows are otherwise immutable, so saving is the only change a cached fragment must notice.
  def cache_version
    saved_at&.to_i.to_s
  end

  # Subagent rows have no place in the main thread to link back to, so only main-thread bubbles are saveable.
  def saveable?
    kind.in?(TALLIED_KINDS) && !sidechain
  end

  def self.index_for_search(scope)
    connection.execute(<<~SQL)
      INSERT INTO messages_fts (rowid, body)
      #{scope.where(kind: SEARCHABLE_KINDS).where.not(body: nil).select(:id, :body).to_sql}
    SQL
  end

  def self.unindex_for_search(scope)
    connection.execute("DELETE FROM messages_fts WHERE rowid IN (#{scope.select(:id).to_sql})")
  end

  # Every word must match; the last one also matches as a prefix so results narrow while typing.
  def self.search(query, limit: 100)
    words = query.to_s.scan(/[[:alnum:]_]+/)
    return none if words.empty?

    match = words.map { %("#{it}") }.join(" ") + "*"
    joins("JOIN messages_fts ON messages_fts.rowid = messages.id")
      .where("messages_fts MATCH ?", match)
      .where(sidechain: false)
      .select("messages.*", sanitize_sql_array([ "snippet(messages_fts, 0, ?, ?, '…', 24) AS snippet", MARK_START, MARK_END ]))
      .order(Arel.sql("bm25(messages_fts)"))
      .limit(limit)
  end

  def tool_input_hash
    @tool_input_hash ||= tool_input.present? ? JSON.parse(tool_input) : {}
  end

  def results
    conversation.messages.where(tool_use_id: tool_use_id, kind: %w[tool_result image]).order(:id)
  end

  def subagent_transcript
    conversation.transcripts.find_by(tool_use_id: tool_use_id)
  end
end
