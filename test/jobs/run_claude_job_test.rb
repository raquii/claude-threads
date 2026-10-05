require "test_helper"

class RunClaudeJobTest < ActiveJob::TestCase
  setup do
    @dir = Dir.mktmpdir
    @args_file = File.join(@dir, "args")
    fake_claude = File.join(@dir, "claude")
    File.write(fake_claude, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$@" > #{@args_file}
      cat > /dev/null
      echo '{"type":"result","is_error":false,"result":"ok","permission_denials":[{"tool_name":"Bash"}]}'
    SH
    File.chmod(0o755, fake_claude)
    Setting.current.update!(claude_path: fake_claude)

    project = Project.create!(dir_name: "p")
    @conversation = project.conversations.create!(session_uuid: "s1", cwd: @dir)
    @conversation.transcripts.create!(path: File.join(@dir, "s1.jsonl"))
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "passes mode, model, and effort, and denies permission prompts" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "acceptEdits", model: "opus", effort: "max")
    RunClaudeJob.perform_now(run)

    args = File.read(@args_file).lines(chomp: true)
    assert_equal [ "-p", "--resume", "s1", "--permission-mode", "acceptEdits", "--permission-prompts", "none",
      "--model", "opus", "--effort", "max", "--output-format", "stream-json", "--verbose" ], args
    assert_equal "succeeded", run.reload.status
    assert_equal [ "Bash" ], run.denied_tool_names
  end

  test "a finished reply starts the next queued message" do
    run = @conversation.runs.create!(prompt: "first", permission_mode: "manual")
    queued = @conversation.runs.create!(prompt: "second", permission_mode: "manual", status: "waiting")

    assert_enqueued_with(job: RunClaudeJob, args: [ queued ]) { RunClaudeJob.perform_now(run) }
    assert_equal "queued", queued.reload.status
  end

  test "leaves model and effort to the CLI when not chosen" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual")
    RunClaudeJob.perform_now(run)

    args = File.read(@args_file).lines(chomp: true)
    assert_not_includes args, "--model"
    assert_not_includes args, "--effort"
  end
end
