class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    return if @query.empty?

    @conversations = Conversation
      .where("custom_name LIKE :q ESCAPE '\\' OR agent_name LIKE :q ESCAPE '\\' OR ai_title LIKE :q ESCAPE '\\'",
        q: "%#{Conversation.sanitize_sql_like(@query)}%")
      .includes(:project).recent_first.limit(20)
    @hits = Message.search(@query).includes(conversation: :project).to_a
  end
end
