class BackfillConversationModelSettings < ActiveRecord::Migration[8.1]
  FIELDS = %i[last_model last_effort last_permission_mode].freeze

  def up
    select_rows("SELECT conversation_id, path FROM transcripts WHERE agent_id IS NULL").each do |conversation_id, path|
      next unless File.exist?(path)

      found = {}
      File.foreach(path) do |line|
        next unless line.include?('"model"') || line.include?('"effort"') || line.include?('"permissionMode"')

        data = JSON.parse(line) rescue next
        found.merge!(TranscriptLine.new(data).metadata.slice(*FIELDS).compact)
      end
      next if found.empty?

      assignments = found.keys.map { |field| "#{field} = ?" }.join(", ")
      exec_update(sanitize_sql_array([ "UPDATE conversations SET #{assignments} WHERE id = ?", *found.values, conversation_id ]))
    end
  end

  def down
  end

  private

  def sanitize_sql_array(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
