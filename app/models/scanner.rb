class Scanner
  def initialize(setting = Setting.current)
    @setting = setting
  end

  def run
    Dir.glob(File.join(@setting.projects_root, "*", "*.jsonl")).each { |path| guard(path) { sync_main(path) } }
    Dir.glob(File.join(@setting.projects_root, "*", "*", "subagents", "agent-*.jsonl")).each { |path| guard(path) { sync_subagent(path) } }
    @setting.update!(last_scanned_at: Time.current)
  end

  def sync_conversation(conversation)
    main = conversation.main_transcript
    return unless main

    guard(main.path) { main.ingest! } if File.exist?(main.path)
    Dir.glob(File.join(File.dirname(main.path), conversation.session_uuid, "subagents", "agent-*.jsonl")).each do |path|
      guard(path) { sync_subagent(path) }
    end
  end

  private

  def guard(path)
    yield
  rescue => error
    Rails.logger.error("[Scanner] #{path}: #{error.class}: #{error.message}")
  end

  def sync_main(path)
    transcript = Transcript.find_by(path: path)
    return transcript.ingest! if transcript
    return if File.zero?(path)

    project = Project.find_or_create_by!(dir_name: File.basename(File.dirname(path)))
    conversation = project.conversations.find_or_create_by!(session_uuid: File.basename(path, ".jsonl"))
    conversation.transcripts.create!(path: path).ingest!
  end

  def sync_subagent(path)
    transcript = Transcript.find_by(path: path)
    return transcript.ingest! if transcript

    session_uuid = File.basename(File.dirname(path, 2))
    conversation = Conversation.find_by(session_uuid: session_uuid)
    return unless conversation

    meta_path = path.delete_suffix(".jsonl") + ".meta.json"
    meta = File.exist?(meta_path) ? JSON.parse(File.read(meta_path)) : {}
    conversation.transcripts.create!(
      path: path,
      agent_id: File.basename(path, ".jsonl").delete_prefix("agent-"),
      agent_type: meta["agentType"],
      description: meta["description"],
      tool_use_id: meta["toolUseId"]
    ).ingest!
  end
end
