require "test_helper"

class NotesTest < ActionDispatch::IntegrationTest
  setup do
    @dir = Dir.mktmpdir
    path = File.join(@dir, "s1.jsonl")
    File.write(path, "")
    @conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1", cwd: @dir, ai_title: "Rounding fix")
    transcript = @conversation.transcripts.create!(path: path)
    @message = Message.create!(conversation: @conversation, transcript: transcript, kind: "text", uuid: "line-1", body: "Found the bug")
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "the conversation note is created, edited, and deleted by clearing it" do
    patch conversation_note_path(@conversation), params: { note: { body: "**First** pass" } }, as: :turbo_stream
    assert_equal "**First** pass", @conversation.notes.on_conversation.sole.body
    assert_match %r{<strong>First</strong>}, response.body

    patch conversation_note_path(@conversation), params: { note: { body: "Second pass" } }, as: :turbo_stream
    assert_equal [ "Second pass" ], @conversation.notes.pluck(:body)

    patch conversation_note_path(@conversation), params: { note: { body: "" } }, as: :turbo_stream
    assert_empty @conversation.notes
  end

  test "a message note is kept apart from the conversation note and finds its message" do
    patch conversation_note_path(@conversation), params: { note: { body: "Overall" } }, as: :turbo_stream
    patch conversation_note_path(@conversation), params: { note: { body: "About this reply", message_uuid: "line-1" } }, as: :turbo_stream

    assert_equal 2, @conversation.notes.count
    assert_equal @message, @conversation.notes.on_messages.sole.message
    assert_select "[data-note-message-uuid='line-1'] .note-body", text: "About this reply"
  end

  test "only one conversation note and one note per message can exist" do
    @conversation.notes.create!(body: "a")
    @conversation.notes.create!(body: "b", message_uuid: "line-1")

    assert_not @conversation.notes.new(body: "c").valid?
    assert_not @conversation.notes.new(body: "d", message_uuid: "line-1").valid?
  end

  test "preview renders markdown with file links resolved against the session" do
    post preview_conversation_note_path(@conversation), params: { body: "See [x](app/x.rb#L3)" }

    assert_match %(data-file-path="#{@dir}/app/x.rb"), response.body
  end

  test "the conversation page has the notes panel and a note button on each message" do
    @conversation.notes.create!(body: "On the reply", message_uuid: "line-1")

    get conversation_path(@conversation)

    assert_select ".notes-panel #notes_panel_body"
    assert_select "#notes_toggle_count", text: "1"
    assert_select "#message_#{@message.id}[data-message-uuid='line-1'] .note-btn[data-message-uuid='line-1']"
  end

  test "the notes page lists notes by conversation" do
    @conversation.notes.create!(body: "Overall")
    @conversation.notes.create!(body: "On the reply", message_uuid: "line-1")

    get notes_path

    assert_select ".notes-group .hit-title", text: "Rounding fix"
    assert_select ".notes-group-item", count: 2
    assert_select "a.notes-group-label", text: /Found the bug/
  end
end
