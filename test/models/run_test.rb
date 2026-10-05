require "test_helper"

class RunTest < ActiveSupport::TestCase
  setup do
    @conversation = Project.create!(dir_name: "p").conversations.create!(session_uuid: "s1")
  end

  test "a running run whose process is gone is failed and no longer active" do
    dead_pid = Process.spawn("true").tap { Process.wait(it) }
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "default", status: "running", pid: dead_pid, started_at: Time.current)

    assert_nil @conversation.active_run
    assert_equal "failed", run.reload.status
  end

  test "a running run with a live process stays active" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "default", status: "running", pid: Process.pid, started_at: Time.current)

    assert_equal run, @conversation.active_run
  end

  test "a run that never recorded a pid is abandoned only after the grace period" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "default", status: "running", started_at: Time.current)
    assert_equal run, @conversation.active_run

    run.update!(started_at: 2.minutes.ago)
    assert_nil @conversation.active_run
  end

  test "queued runs are left for the job to pick up" do
    run = @conversation.runs.create!(prompt: "hi", permission_mode: "default")

    assert_equal run, @conversation.active_run
  end
end
