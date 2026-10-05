class RunsController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    attributes = params.expect(run: %i[prompt permission_mode model effort])
    # A send must never fail for want of a mode; fall back to how the session last ran.
    attributes[:permission_mode] = attributes[:permission_mode].presence || @conversation.last_permission_mode || "manual"

    # SQLite's immediate transaction serializes this check with the insert, so two quick sends can't both start.
    run = Run.transaction do
      next if @conversation.live_session

      status = @conversation.active_run ? "waiting" : "queued"
      @conversation.runs.create(attributes.merge(status: status))
    end
    return render_send_error("This session is open in another Claude Code process. Send from there, or close it first.", :conflict) unless run
    return render_send_error("Couldn't send: #{run.errors.full_messages.to_sentence}.", :unprocessable_entity) unless run.persisted?

    RunClaudeJob.perform_later(run) if run.status == "queued"
    render_status
  end

  def destroy
    run = Run.find(params[:id])
    @conversation = run.conversation
    run.destroy! if run.status == "waiting"
    render_status
  end

  def cancel
    run = Run.find(params[:id])
    Process.kill("TERM", run.pid) if run.pid && run.status == "running"
    head :no_content
  rescue Errno::ESRCH
    head :no_content
  end

  private

  def render_status
    @run = @conversation.latest_run
    render :create, formats: :turbo_stream
  end

  def render_send_error(message, status)
    render turbo_stream: turbo_stream.update("composer_error", message), status: status
  end
end
