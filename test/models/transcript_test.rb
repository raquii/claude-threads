require "test_helper"

class TranscriptTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "s1.jsonl")
    conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1")
    @transcript = conversation.transcripts.create!(path: @path)
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "ingests only complete appended lines" do
    File.write(@path, line("one") + line("two")[0, 10])
    @transcript.ingest!
    assert_equal [ "one" ], @transcript.messages.pluck(:body)

    File.write(@path, line("one") + line("two") + line("three"))
    @transcript.ingest!
    assert_equal %w[one two three], @transcript.messages.order(:id).pluck(:body)
    assert_equal "one", @transcript.conversation.first_prompt
    assert_equal 3, @transcript.conversation.message_count
  end

  test "re-reads a file that shrank" do
    File.write(@path, line("one") + line("two"))
    @transcript.ingest!
    File.write(@path, line("fresh"))
    @transcript.ingest!

    assert_equal [ "fresh" ], @transcript.reload.messages.pluck(:body)
  end

  test "saves survive a re-read of the file" do
    File.write(@path, line("keep me", uuid: "u1") + line("other", uuid: "u2"))
    @transcript.ingest!
    @transcript.messages.find_by(uuid: "u1").update!(saved_at: Time.current)

    File.write(@path, line("keep me", uuid: "u1"))
    @transcript.ingest!

    assert_equal [ "keep me" ], @transcript.reload.messages.saved.pluck(:body)
  end

  test "saves wait across ingests when the rewritten file is caught empty" do
    File.write(@path, line("keep me", uuid: "u1") + line("other", uuid: "u2"))
    @transcript.ingest!
    @transcript.messages.find_by(uuid: "u1").update!(saved_at: Time.current)

    File.write(@path, "")
    @transcript.ingest!
    assert_equal 1, @transcript.reload.carried_saves.size

    File.write(@path, line("other", uuid: "u2"))
    @transcript.ingest!
    File.write(@path, line("other", uuid: "u2") + line("keep me", uuid: "u1"))
    @transcript.ingest!

    assert_equal [ "keep me" ], @transcript.reload.messages.saved.pluck(:body)
    assert_nil @transcript.carried_saves
  end

  test "a stale copy of the transcript does not insert lines twice" do
    File.write(@path, line("one"))
    stale = Transcript.find(@transcript.id)
    @transcript.ingest!
    stale.ingest!

    assert_equal [ "one" ], @transcript.messages.pluck(:body)
    assert_equal 1, @transcript.conversation.reload.message_count
  end

  test "a re-read bumps the generation and clears titles from the old content" do
    File.write(@path, line("old first") + { type: "ai-title", aiTitle: "Old title" }.to_json + "\n")
    @transcript.ingest!
    File.write(@path, line("new"))
    @transcript.ingest!

    conversation = @transcript.reload.conversation
    assert_equal 1, @transcript.generation
    assert_equal "new", conversation.first_prompt
    assert_nil conversation.ai_title
  end

  private

  def line(text, uuid: nil)
    { type: "user", uuid: uuid, timestamp: "2026-10-05T12:00:00Z", message: { role: "user", content: text } }.compact.to_json + "\n"
  end
end
