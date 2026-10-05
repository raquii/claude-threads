require "test_helper"

class MessageSearchTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "s1.jsonl")
    conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1")
    @transcript = conversation.transcripts.create!(path: @path)
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "finds prompts and replies with stemming and prefix matching, not tool calls" do
    File.write(@path, prompt("We are batching the requests") + reply("Batched calls look fine") + tool_call("batching"))
    @transcript.ingest!

    assert_equal 2, Message.search("batch").to_a.size
    assert_equal [ "prompt" ], Message.search("requ").map(&:kind)
    assert_includes Message.search("batched calls").first.snippet, "#{Message::MARK_START}Batched#{Message::MARK_END}"
  end

  test "ignores punctuation that would be FTS syntax" do
    File.write(@path, prompt("hello world"))
    @transcript.ingest!

    assert_equal 1, Message.search(%q{hello" ( * ^}).to_a.size
    assert_empty Message.search("***").to_a
  end

  test "a re-read file replaces its index entries" do
    File.write(@path, prompt("alpha one") + prompt("alpha two"))
    @transcript.ingest!
    File.write(@path, prompt("beta"))
    @transcript.ingest!

    assert_empty Message.search("alpha").to_a
    assert_equal 1, Message.search("beta").to_a.size
  end

  private

  def prompt(text)
    { type: "user", message: { role: "user", content: text } }.to_json + "\n"
  end

  def reply(text)
    { type: "assistant", message: { role: "assistant", content: [ { type: "text", text: text } ] } }.to_json + "\n"
  end

  def tool_call(command)
    { type: "assistant", message: { content: [ { type: "tool_use", id: "t1", name: "Bash", input: { command: command } } ] } }.to_json + "\n"
  end
end
