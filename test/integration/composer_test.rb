require "test_helper"

class ComposerTest < ActionDispatch::IntegrationTest
  setup do
    @dir = Dir.mktmpdir
    path = File.join(@dir, "s1.jsonl")
    File.write(path, "")
    @conversation = Project.create!(dir_name: "p").conversations.create!(
      session_uuid: "s1", cwd: @dir, last_model: "claude-opus-5-5", last_effort: "high", last_permission_mode: "acceptEdits"
    )
    @conversation.transcripts.create!(path: path)
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "the options menu starts on the session's model, effort, and mode" do
    get conversation_path(@conversation)

    assert_select ".run-options-trigger", text: /Opus 5.5 · high · Accept edits/
    assert_select "input[name='run[model]'][value='claude-opus-5-5'][checked]"
    assert_select "input[name='run[effort]'][value='high'][checked]"
    assert_select "input[name='run[permission_mode]'][value='acceptEdits'][checked]"
  end

  test "the session's model replaces its family's alias in the model list" do
    get conversation_path(@conversation)

    assert_select "input[name='run[model]']", count: 4
    assert_select "input[name='run[model]'][value='opus']", count: 0
    assert_select "input[name='run[model]'][value='sonnet']", count: 1
  end
end
