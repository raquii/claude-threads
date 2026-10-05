class ApplicationController < ActionController::Base
  GROUP_STATE_COOKIE = "sidebar_groups"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :sidebar_locals

  private

  # Group open/closed state lives in a cookie so the server renders it, and reloads never override it.
  def sidebar_locals(current_id:)
    group_state = JSON.parse(cookies[GROUP_STATE_COOKIE].to_s) rescue {}
    {
      projects: Project.where(id: Conversation.select(:project_id)).order(last_activity_at: :desc).includes(:conversations),
      current_id: current_id,
      setting: Setting.current,
      group_state: group_state.is_a?(Hash) ? group_state : {}
    }
  end
end
