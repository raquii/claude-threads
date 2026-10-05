class RunsController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    # SQLite's immediate transaction serializes this check with the insert, so two quick sends can't both pass.
    @run = Run.transaction do
      @conversation.runs.create!(params.expect(run: %i[prompt permission_mode])) unless @conversation.active_run || @conversation.live_session
    end
    return head :conflict unless @run

    RunClaudeJob.perform_later(@run)
    render formats: :turbo_stream
  end

  def cancel
    run = Run.find(params[:id])
    Process.kill("TERM", run.pid) if run.pid && run.status == "running"
    head :no_content
  rescue Errno::ESRCH
    head :no_content
  end
end
