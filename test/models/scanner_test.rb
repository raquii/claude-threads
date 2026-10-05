require "test_helper"

class ScannerTest < ActiveSupport::TestCase
  test "scans the sample sessions, links the subagent, and reads titles" do
    Scanner.new.run

    assert_equal 3, Conversation.count
    shop = Conversation.find_by!(session_uuid: "11111111-1111-4111-8111-111111111111")
    assert_equal "Fix checkout rounding bug", shop.title
    assert_equal "/tmp/sample-shop", shop.cwd
    assert_equal "toolu_s1_agent", shop.transcripts.find_by!(agent_id: "a1sample").tool_use_id
    assert_equal 1, shop.messages.where(kind: "summary").count
    assert_equal [ "claude-opus-5-5", "high", "acceptEdits" ], [ shop.last_model, shop.last_effort, shop.last_permission_mode ]
    assert_equal "manual", Conversation.find_by!(session_uuid: "33333333-3333-4333-8333-333333333333").last_permission_mode
    assert_equal "API v1 cleanup", Conversation.find_by!(session_uuid: "33333333-3333-4333-8333-333333333333").title
  end

  test "a second scan adds nothing" do
    Scanner.new.run
    count = Message.count
    Scanner.new.run

    assert_equal count, Message.count
  end
end
