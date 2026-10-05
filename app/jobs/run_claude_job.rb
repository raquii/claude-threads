require "open3"

# Claude Code appends the resumed turn to the session's own JSONL file, so this job
# only drives the process; the conversation poller picks the new lines up from disk.
class RunClaudeJob < ApplicationJob
  def perform(run)
    conversation = run.conversation
    # No one can answer a permission prompt here, so prompts are denied outright and listed afterwards.
    command = [
      Setting.current.claude_path, "-p",
      "--resume", conversation.session_uuid,
      "--permission-mode", run.permission_mode,
      "--permission-prompts", "none",
      *([ "--model", run.model ] if run.model),
      *([ "--effort", run.effort ] if run.effort),
      "--output-format", "stream-json", "--verbose"
    ]
    run.update!(status: "running", started_at: Time.current)

    result = nil
    stderr_output = nil
    exit_status = nil
    Open3.popen3({ "CLAUDECODE" => nil }, *command, chdir: conversation.cwd) do |stdin, stdout, stderr, wait|
      run.update!(pid: wait.pid)
      stdin.write(run.prompt)
      stdin.close
      stderr_reader = Thread.new { stderr.read }
      stdout.each_line do |line|
        data = JSON.parse(line) rescue next
        result = data if data["type"] == "result"
      end
      stderr_output = stderr_reader.value
      exit_status = wait.value.exitstatus
    end

    denied = Array(result&.dig("permission_denials")).filter_map { |denial| denial["tool_name"] }.uniq
    failed = exit_status != 0 || result.nil? || result["is_error"]
    run.update!(
      status: failed ? "failed" : "succeeded",
      exit_status: exit_status,
      error: failed ? (result&.dig("result").presence || stderr_output.presence || "claude exited (status #{exit_status}) without sending a reply") : nil,
      denied_tools: denied.any? ? denied.to_json : nil,
      finished_at: Time.current
    )
  rescue => error
    run.update!(status: "failed", error: "#{error.class}: #{error.message}", finished_at: Time.current)
  ensure
    if conversation
      Scanner.new.sync_conversation(conversation)
      conversation.start_next_run!
    end
  end
end
