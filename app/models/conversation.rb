class Conversation < ApplicationRecord
  belongs_to :project
  has_many :transcripts, dependent: :destroy
  has_many :messages, dependent: :delete_all
  has_many :runs, dependent: :destroy
  has_one :main_transcript, -> { where(agent_id: nil) }, class_name: "Transcript"

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :recent_first, -> { order(last_activity_at: :desc) }

  def title
    custom_name.presence || agent_name.presence || ai_title.presence || first_prompt&.truncate(80).presence || session_uuid
  end

  def archived?
    archived_at.present?
  end

  def active_run
    run = runs.where(status: %w[queued running]).order(:id).last
    return run unless run&.fail_if_abandoned!

    start_next_run!
    nil
  end

  # The run whose reply the status line describes; queued messages haven't started yet.
  def latest_run
    runs.where.not(status: "waiting").order(:id).last
  end

  # Messages sent while a reply is running wait here, like the CLI's queue, and go out one at a time.
  def waiting_runs
    runs.where(status: "waiting").order(:id)
  end

  def start_next_run!
    run = Run.transaction do
      next if active_run

      waiting_runs.first&.tap { it.update!(status: "queued") }
    end
    RunClaudeJob.perform_later(run) if run
  end

  # Another Claude Code process holding this session, from the registry Claude Code keeps in ~/.claude/sessions.
  # Resuming alongside it splits the history, and that process never sees the turns this app sends.
  def live_session
    registry = File.join(File.dirname(Setting.current.projects_root), "sessions", "*.json")
    own_pid = active_run&.pid
    Dir.glob(registry).each do |path|
      entry = JSON.parse(File.read(path)) rescue next
      next unless entry["sessionId"] == session_uuid && entry["pid"] != own_pid

      return entry if LocalProcess.alive?(entry["pid"])
    end
    nil
  end

  def resumable?
    cwd.present? && File.directory?(cwd) && main_transcript.present? && File.exist?(main_transcript.path)
  end

  def absorb!(metadata, rows, from_subagent:)
    activity = [ last_activity_at, metadata[:sent_at] ].compact.max
    unless from_subagent
      self.cwd ||= metadata[:first_cwd]
      assign_attributes(metadata.slice(:ai_title, :agent_name, :git_branch, :continued_in_session_uuid,
        :last_model, :last_effort, :last_permission_mode))
      self.first_prompt ||= rows.find { |row| row[:kind] == "prompt" && !row[:sidechain] }&.dig(:body)
      self.message_count += rows.count { |row| row[:kind].in?(Message::TALLIED_KINDS) && !row[:sidechain] }
    end
    self.last_activity_at = activity
    save!

    project.cwd ||= cwd
    project.last_activity_at = [ project.last_activity_at, activity ].compact.max
    project.save!
  end

end
