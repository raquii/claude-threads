class Run < ApplicationRecord
  PERMISSION_MODES = {
    "default" => "Ask (blocked tools fail)",
    "acceptEdits" => "Accept edits",
    "plan" => "Plan only",
    "bypassPermissions" => "Bypass all"
  }.freeze

  belongs_to :conversation

  validates :prompt, presence: true
  validates :permission_mode, inclusion: { in: PERMISSION_MODES.keys }

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
