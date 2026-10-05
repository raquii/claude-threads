class Run < ApplicationRecord
  # The values `claude --permission-mode` accepts, in the CLI's order.
  PERMISSION_MODES = {
    "manual" => "Manual",
    "acceptEdits" => "Accept edits",
    "auto" => "Auto",
    "plan" => "Plan",
    "dontAsk" => "Don't ask",
    "bypassPermissions" => "Bypass permissions"
  }.freeze
  # How each mode behaves here, where no one can answer a permission prompt.
  PERMISSION_MODE_HINTS = {
    "manual" => "Refuses anything that needs approval",
    "acceptEdits" => "Edits files; refuses other approvals",
    "auto" => "Claude Code's classifier decides",
    "plan" => "Plans without making changes",
    "dontAsk" => "Runs only pre-approved tools",
    "bypassPermissions" => "Runs everything without asking"
  }.freeze
  # Older Claude Code versions recorded manual mode as "default".
  LEGACY_PERMISSION_MODES = { "default" => "manual" }.freeze
  MODELS = { "fable" => "Fable", "opus" => "Opus", "sonnet" => "Sonnet", "haiku" => "Haiku" }.freeze
  EFFORTS = %w[low medium high xhigh max].freeze

  belongs_to :conversation

  validates :prompt, presence: true
  validates :permission_mode, inclusion: { in: PERMISSION_MODES.keys }, on: :create
  validates :effort, inclusion: { in: EFFORTS }, allow_nil: true, on: :create
  # An alias or a full model name such as "claude-opus-5-5[1m]".
  validates :model, format: { with: /\A[a-z0-9][a-z0-9.\-\[\]]*\z/i }, allow_nil: true, on: :create

  normalizes :model, :effort, with: ->(value) { value.presence }

  def self.permission_mode_for(recorded)
    mode = LEGACY_PERMISSION_MODES.fetch(recorded, recorded)
    mode if PERMISSION_MODES.key?(mode)
  end

  PID_GRACE = 1.minute

  def finished?
    status.in?(%w[succeeded failed])
  end

  # A worker that dies mid-run never reaches the job's rescue or ensure, leaving the run "running" forever.
  # Queued runs are left alone: Solid Queue keeps their job and runs it once the worker is back.
  def fail_if_abandoned!
    return false unless status == "running"
    return false if pid ? LocalProcess.alive?(pid) : started_at.nil? || started_at > PID_GRACE.ago

    update!(status: "failed", error: "The claude process ended without reporting back, likely because the app restarted.", finished_at: Time.current)
    true
  end

  def denied_tool_names
    denied_tools.present? ? JSON.parse(denied_tools) : []
  end
end
