require "test_helper"

class GuardsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1", ai_title: "fix_auth cleanup")
  end

  test "title search treats underscores literally" do
    Project.first.conversations.create!(session_uuid: "s2", ai_title: "fixXauth decoy")

    get search_path(q: "fix_auth")

    assert_select ".search .hit-title", text: "fix_auth cleanup", count: 1
    assert_select ".search .hit-title", text: "fixXauth decoy", count: 0
  end

  test "a send while a reply is running waits in the queue instead of starting" do
    @conversation.runs.create!(prompt: "first", permission_mode: "manual")

    assert_no_enqueued_jobs only: RunClaudeJob do
      post conversation_runs_path(@conversation), params: { run: { prompt: "second", permission_mode: "manual" } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal [ "second" ], @conversation.waiting_runs.pluck(:prompt)
    assert_select ".run-queue-prompt", text: "second"
  end

  test "a send without a permission mode uses the session's last mode" do
    @conversation.update!(last_permission_mode: "acceptEdits")

    post conversation_runs_path(@conversation), params: { run: { prompt: "hi", model: "opus" } }, as: :turbo_stream

    assert_response :success
    assert_equal "acceptEdits", @conversation.runs.last.permission_mode
  end

  test "a refused send says why in the composer" do
    post conversation_runs_path(@conversation), params: { run: { prompt: "hi", permission_mode: "manual", effort: "turbo" } }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match %r{<turbo-stream action="update" target="composer_error">}, response.body
    assert_match "Effort is not included in the list", response.body
  end

  test "a send to a session open in another process is refused with an explanation" do
    Dir.mktmpdir do |root|
      Setting.current.update!(projects_root: File.join(root, "projects"))
      FileUtils.mkdir_p(File.join(root, "sessions"))
      File.write(File.join(root, "sessions", "1.json"), { pid: Process.pid, sessionId: "s1", kind: "interactive" }.to_json)

      post conversation_runs_path(@conversation), params: { run: { prompt: "hi", permission_mode: "manual" } }, as: :turbo_stream
    end

    assert_response :conflict
    assert_match "open in another Claude Code process", response.body
    assert_empty @conversation.runs
  end

  test "a queued message can be removed, but a running one cannot" do
    running = @conversation.runs.create!(prompt: "first", permission_mode: "manual")
    queued = @conversation.runs.create!(prompt: "second", permission_mode: "manual", status: "waiting")

    delete run_path(queued), as: :turbo_stream
    delete run_path(running), as: :turbo_stream

    assert_equal [ running ], @conversation.runs.to_a
  end

  test "subagent messages cannot be saved" do
    transcript = @conversation.transcripts.create!(path: "/tmp/none.jsonl", agent_id: "a1")
    message = Message.create!(conversation: @conversation, transcript: transcript, kind: "text", body: "x", sidechain: true)

    post message_save_path(message), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_nil message.reload.saved_at
  end
end
