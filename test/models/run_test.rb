require "test_helper"

class RunTest < ActiveSupport::TestCase
  setup do
    @conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1")
  end

  test "a running run whose process is gone is failed and no longer active" do
    dead_pid = Process.spawn("true").tap { Process.wait(it) }
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual", status: "running", pid: dead_pid, started_at: Time.current)

    assert_nil @conversation.active_run
    assert_equal "failed", run.reload.status
  end

  test "an abandoned run hands off to the next queued message" do
    dead_pid = Process.spawn("true").tap { Process.wait(it) }
    @conversation.runs.create!(prompt: "hi", permission_mode: "manual", status: "running", pid: dead_pid, started_at: Time.current)
    queued = @conversation.runs.create!(prompt: "next", permission_mode: "manual", status: "waiting")

    assert_nil @conversation.active_run
    assert_equal "queued", queued.reload.status
    assert_equal queued, @conversation.active_run
  end

  test "a running run with a live process stays active" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual", status: "running", pid: Process.pid, started_at: Time.current)

    assert_equal run, @conversation.active_run
  end

  test "a run that never recorded a pid is abandoned only after the grace period" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual", status: "running", started_at: Time.current)
    assert_equal run, @conversation.active_run

    run.update!(started_at: 2.minutes.ago)
    assert_nil @conversation.active_run
  end

  test "accepts the CLI's modes, model names, and efforts and rejects anything else" do
    valid = @conversation.runs.new(prompt: "hi", permission_mode: "auto", model: "claude-opus-5-5[1m]", effort: "max")
    assert valid.valid?

    assert_not @conversation.runs.new(prompt: "hi", permission_mode: "default").valid?
    assert_not @conversation.runs.new(prompt: "hi", permission_mode: "manual", effort: "turbo").valid?
    assert_not @conversation.runs.new(prompt: "hi", permission_mode: "manual", model: "opus; rm -rf /").valid?
  end

  test "blank model and effort mean the CLI defaults" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual", model: "", effort: "")

    assert_nil run.model
    assert_nil run.effort
  end

  test "runs saved with a retired mode can still be updated" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual")
    run.update_column(:permission_mode, "default")

    assert run.reload.update(status: "failed")
  end

  test "queued runs are left for the job to pick up" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "manual")

    assert_equal run, @conversation.active_run
  end
end
