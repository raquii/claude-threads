# Turns a single JSONL line from a Claude Code transcript into message rows plus conversation metadata.
class TranscriptLine
  MAX_BODY = 200_000
  META_TAGS = %w[
    local-command-caveat task-notification task-id ide_opened_file ide_selection
    system-reminder fork-source user-prompt-submit-hook
  ].freeze

  attr_reader :rows, :metadata

  def initialize(data)
    @data = data
    @rows = []
    @metadata = {}
    parse
  end

  private

  def parse
    case @data["type"]
    when "user" then parse_user
    when "assistant" then parse_assistant
    when "system" then parse_system
    when "ai-title" then @metadata[:ai_title] = @data["aiTitle"]
    when "agent-name" then @metadata[:agent_name] = @data["agentName"]
    when "summary" then @metadata[:ai_title] = @data["summary"]
    when "continued-in"
      @metadata[:continued_in_session_uuid] = @data["continuedInSessionId"]
      add "marker", body: "Continued in a new session", tool_use_id: @data["continuedInSessionId"]
    end

    @metadata[:cwd] = @data["cwd"] if @data["cwd"]
    @metadata[:git_branch] = @data["gitBranch"] if @data["gitBranch"].present?
    @metadata[:last_permission_mode] = Run.permission_mode_for(@data["permissionMode"]) if @data["permissionMode"]
    @metadata[:sent_at] = sent_at if sent_at
  end

  def parse_user
    content = @data.dig("message", "content")
    if content.is_a?(String)
      add_user_text(content)
    else
      Array(content).each do |block|
        case block["type"]
        when "text" then add_user_text(block["text"])
        when "image" then add_image(block)
        when "tool_result" then add_tool_result(block)
        end
      end
    end
  end

  def add_user_text(text)
    return if text.blank?

    if @data["isCompactSummary"]
      add "summary", body: text
    elsif @data["isMeta"] || meta_tag?(text)
      add "meta", body: text
    elsif text.start_with?("<command-name>", "<command-message>")
      name = text[%r{<command-name>(.*?)</command-name>}m, 1] || text[%r{<command-message>(.*?)</command-message>}m, 1]
      args = text[%r{<command-args>(.*?)</command-args>}m, 1]
      add "command", body: [ name, args ].compact_blank.join(" ")
    elsif text.start_with?("<local-command-stdout>", "<local-command-stderr>")
      add "command", body: text.gsub(%r{</?local-command-std(out|err)>}, ""), tool_name: "output"
    elsif text.start_with?("<bash-input>")
      add "command", body: "! #{text[%r{<bash-input>(.*?)</bash-input>}m, 1]}"
    elsif text.start_with?("<bash-stdout>", "<bash-stderr>")
      add "command", body: text.gsub(%r{</?bash-std(out|err)>}, ""), tool_name: "output"
    else
      add "prompt", body: text
    end
  end

  def meta_tag?(text)
    tag = text[/\A\s*<([\w-]+)[\s>]/, 1]
    tag.present? && META_TAGS.include?(tag)
  end

  def add_image(block, tool_use_id: nil)
    source = block["source"] || {}
    return unless source["type"] == "base64"

    add "image", body: source["data"], media_type: source["media_type"], tool_use_id: tool_use_id
  end

  def add_tool_result(block)
    content = block["content"]
    text =
      if content.is_a?(String)
        content
      else
        Array(content).filter_map { |part| part["text"] if part["type"] == "text" }.join("\n")
      end
    add "tool_result", body: text, tool_use_id: block["tool_use_id"], is_error: block["is_error"] == true
    Array(content).each { |part| add_image(part, tool_use_id: block["tool_use_id"]) if part.is_a?(Hash) && part["type"] == "image" }
  end

  def parse_assistant
    message = @data["message"] || {}
    # Error and interrupt lines carry "<synthetic>" as their model.
    @metadata[:last_model] = message["model"] if message["model"].to_s.start_with?("claude-")
    @metadata[:last_effort] = @data["effort"] if Run::EFFORTS.include?(@data["effort"])
    Array(message["content"]).each do |block|
      case block["type"]
      when "text"
        add "text", body: block["text"], model: message["model"] if block["text"].present?
      when "thinking"
        add "thinking", body: block["thinking"] if block["thinking"].present?
      when "tool_use", "server_tool_use"
        add "tool_use", tool_name: block["name"], tool_use_id: block["id"], tool_input: block["input"].to_json
      end
    end
  end

  def parse_system
    case @data["subtype"]
    when "compact_boundary"
      meta = @data["compactMetadata"] || {}
      tokens = [ meta["preTokens"], meta["postTokens"] ].compact.map { |n| ActiveSupport::NumberHelper.number_to_human(n, units: { thousand: "k", million: "M" }, precision: 3) }
      label = "Conversation compacted"
      label += " (#{meta["trigger"]}, #{tokens.join(" → ")} tokens)" if tokens.size == 2
      add "marker", body: label
    when "local_command"
      add "command", body: @data["content"].to_s.gsub(/<[^>]+>/, ""), tool_name: "output"
    end
  end

  def add(kind, body: nil, **attrs)
    @rows << {
      kind: kind,
      uuid: @data["uuid"],
      sidechain: @data["isSidechain"] == true,
      body: kind == "image" ? body : body&.truncate(MAX_BODY, omission: "\n\n… [truncated by Claude Threads]"),
      sent_at: sent_at,
      tool_name: nil, tool_use_id: nil, tool_input: nil, media_type: nil, is_error: false, model: nil,
      **attrs
    }
  end

  def sent_at
    return @sent_at if defined?(@sent_at)

    @sent_at = Time.iso8601(@data["timestamp"].to_s) rescue nil
  end
end
