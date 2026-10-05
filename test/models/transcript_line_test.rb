require "test_helper"

class TranscriptLineTest < ActiveSupport::TestCase
  test "user string becomes a prompt" do
    line = TranscriptLine.new("type" => "user", "uuid" => "u1", "timestamp" => "2026-10-05T12:00:00Z", "cwd" => "/tmp/x",
      "message" => { "role" => "user", "content" => "hello" })

    assert_equal [ [ "prompt", "hello" ] ], line.rows.map { [ it[:kind], it[:body] ] }
    assert_equal "/tmp/x", line.metadata[:cwd]
  end

  test "system reminders and isMeta lines are meta" do
    reminder = TranscriptLine.new("type" => "user", "message" => { "content" => [ { "type" => "text", "text" => "<system-reminder>x</system-reminder>" } ] })
    flagged = TranscriptLine.new("type" => "user", "isMeta" => true, "message" => { "content" => "Continue" })

    assert_equal [ "meta" ], reminder.rows.map { it[:kind] }
    assert_equal [ "meta" ], flagged.rows.map { it[:kind] }
  end

  test "assistant lines record model and effort; synthetic models and unknown efforts are ignored" do
    line = TranscriptLine.new("type" => "assistant", "effort" => "xhigh", "message" => { "model" => "claude-opus-5-5", "content" => [] })
    synthetic = TranscriptLine.new("type" => "assistant", "effort" => "turbo", "message" => { "model" => "<synthetic>", "content" => [] })

    assert_equal({ last_model: "claude-opus-5-5", last_effort: "xhigh" }, line.metadata.slice(:last_model, :last_effort))
    assert_empty synthetic.metadata.slice(:last_model, :last_effort).compact
  end

  test "permission modes map the legacy default to manual and drop unknown modes" do
    mode = ->(recorded) { TranscriptLine.new("type" => "permission-mode", "permissionMode" => recorded).metadata[:last_permission_mode] }

    assert_equal "auto", mode.("auto")
    assert_equal "manual", mode.("default")
    assert_nil mode.("yolo")
  end

  test "compaction summaries are not treated as prompts" do
    line = TranscriptLine.new("type" => "user", "isCompactSummary" => true,
      "message" => { "role" => "user", "content" => "This session is being continued from a previous conversation…" })

    assert_equal [ "summary" ], line.rows.map { it[:kind] }
  end

  test "slash commands are parsed" do
    line = TranscriptLine.new("type" => "user", "message" => { "content" => "<command-name>/clear</command-name><command-args>now</command-args>" })

    assert_equal [ [ "command", "/clear now" ] ], line.rows.map { [ it[:kind], it[:body] ] }
  end

  test "assistant blocks split into text, thinking, and tool use" do
    line = TranscriptLine.new("type" => "assistant", "message" => { "model" => "m", "content" => [
      { "type" => "thinking", "thinking" => "hmm" },
      { "type" => "thinking", "thinking" => "", "signature" => "sig" },
      { "type" => "text", "text" => "Done" },
      { "type" => "tool_use", "id" => "toolu_1", "name" => "Bash", "input" => { "command" => "ls" } }
    ] })

    assert_equal %w[thinking text tool_use], line.rows.map { it[:kind] }
    assert_equal({ "command" => "ls" }, JSON.parse(line.rows.last[:tool_input]))
  end

  test "tool results keep text and images under the tool use id" do
    line = TranscriptLine.new("type" => "user", "message" => { "content" => [ { "type" => "tool_result", "tool_use_id" => "toolu_1", "is_error" => true, "content" => [
      { "type" => "text", "text" => "boom" },
      { "type" => "image", "source" => { "type" => "base64", "media_type" => "image/png", "data" => "AAAA" } }
    ] } ] })

    assert_equal [ [ "tool_result", "toolu_1", true ], [ "image", "toolu_1", false ] ], line.rows.map { [ it[:kind], it[:tool_use_id], it[:is_error] ] }
  end

  test "title lines populate metadata" do
    assert_equal "A title", TranscriptLine.new("type" => "ai-title", "aiTitle" => "A title").metadata[:ai_title]
    assert_equal "named", TranscriptLine.new("type" => "agent-name", "agentName" => "named").metadata[:agent_name]
  end
end
