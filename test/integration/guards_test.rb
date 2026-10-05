require "test_helper"

class GuardsTest < ActionDispatch::IntegrationTest
  setup do
    @conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1", ai_title: "fix_auth cleanup")
  end

  test "title search treats underscores literally" do
    Project.first.conversations.create!(session_uuid: "s2", ai_title: "fixXauth decoy")

    get search_path(q: "fix_auth")

    assert_select ".search .hit-title", text: "fix_auth cleanup", count: 1
    assert_select ".search .hit-title", text: "fixXauth decoy", count: 0
  end

  test "a second send while a run is active is refused" do
    @conversation.runs.create!(prompt: "first", permission_mode: "default")

    post conversation_runs_path(@conversation), params: { run: { prompt: "second", permission_mode: "default" } }, as: :turbo_stream

    assert_response :conflict
    assert_equal 1, @conversation.runs.count
  end

  test "subagent messages cannot be saved" do
    transcript = @conversation.transcripts.create!(path: "/tmp/none.jsonl", agent_id: "a1")
    message = Message.create!(conversation: @conversation, transcript: transcript, kind: "text", body: "x", sidechain: true)

    post message_save_path(message), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_nil message.reload.saved_at
  end
end
