module MessagesHelper
  MARKDOWN_OPTIONS = {
    extension: { table: true, strikethrough: true, autolink: true, tasklist: true, footnotes: true },
    render: { unsafe: false, hardbreaks: false }
  }.freeze
  HIGHLIGHT = { syntax_highlighter: { theme: "" } }.freeze
  LANGUAGES = {
    ".rb" => "ruby", ".go" => "go", ".js" => "javascript", ".jsx" => "javascript", ".ts" => "typescript",
    ".tsx" => "typescript", ".py" => "python", ".rs" => "rust", ".sql" => "sql", ".sh" => "bash",
    ".yml" => "yaml", ".yaml" => "yaml", ".json" => "json", ".md" => "markdown", ".erb" => "erb",
    ".html" => "html", ".css" => "css", ".scss" => "scss", ".tf" => "terraform", ".vcl" => "c"
  }.freeze

  # "README.md:5" looks like a scheme, so only "scheme://" and the schemes that never take slashes count as URLs.
  URL_SCHEME = %r{\A(?:[a-z][a-z0-9+.-]*://|(?:mailto|tel|data|javascript|about|blob):)}i
  LINE_SUFFIX = /(?:#L(\d+)(?:-L?\d+)?|:(\d+)(?::\d+)?)\z/

  # Links Claude writes to files are relative to the session's directory; they become file links the
  # file-links controller opens in the configured editor.
  def markdown(text, cwd: nil)
    html = Commonmarker.to_html(text.to_s, options: MARKDOWN_OPTIONS, plugins: HIGHLIGHT)
    return html.html_safe unless html.include?("<a ")

    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("a[href]").each do |link|
      href = URI::RFC2396_PARSER.unescape(link["href"])
      next if href.match?(URL_SCHEME) || href.start_with?("#", "//")

      line = href[LINE_SUFFIX, 1] || href[LINE_SUFFIX, 2]
      path = href.sub(LINE_SUFFIX, "").sub(/[?#].*\z/, "")
      next if path.empty? || (cwd.nil? && !path.start_with?("/", "~"))

      absolute = File.expand_path(path, cwd || Dir.home)
      link["href"] = "file://#{absolute}"
      link["class"] = "file-link"
      link["title"] = [ absolute.sub(Dir.home, "~"), line ].compact.join(":")
      link["data-file-path"] = absolute
      link["data-file-line"] = line if line
    end
    fragment.to_html.html_safe
  end

  def code_block(text, language: nil)
    fence = "`" * [ 3, text.to_s.scan(/`+/).map(&:length).max.to_i + 1 ].max
    markdown("#{fence}#{language}\n#{text}\n#{fence}")
  end

  def language_for(path)
    LANGUAGES[File.extname(path.to_s).downcase]
  end

  def tool_summary(message)
    input = message.tool_input_hash
    summary =
      case message.tool_name
      when "Bash" then input["description"].presence || input["command"]
      when "Read", "Write", "Edit", "MultiEdit", "NotebookEdit" then input["file_path"] || input["notebook_path"]
      when "Grep" then [ input["pattern"], input["path"] || input["glob"] ].compact.join("  in  ")
      when "Glob" then input["pattern"]
      when "Agent", "Task" then input["description"]
      when "WebFetch" then input["url"]
      when "WebSearch" then input["query"]
      when "Skill" then input["skill"]
      when "TodoWrite" then "#{Array(input["todos"]).size} todos"
      else input.values.find { |value| value.is_a?(String) }
      end
    summary.to_s.lines.first.to_s.strip.truncate(140).sub(Dir.home, "~")
  end

  def diff_lines(old_text, new_text)
    lines = []
    removed = []
    added = []
    flush = -> { lines.concat(removed.map { [ "-", it ] }, added.map { [ "+", it ] }); removed.clear; added.clear }
    Diff::LCS.sdiff(old_text.to_s.lines, new_text.to_s.lines).each do |change|
      if change.action == "="
        flush.call
        lines << [ " ", change.old_element ]
      else
        removed << change.old_element if change.old_element && change.action != "+"
        added << change.new_element if change.new_element && change.action != "-"
      end
    end
    flush.call
    lines
  end

  def highlighted_snippet(snippet)
    h(snippet.to_s.squish).gsub(Message::MARK_START, "<mark>").gsub(Message::MARK_END, "</mark>").html_safe
  end

  def note_icon(filled: false)
    tag.svg(class: "note-icon", viewBox: "0 0 24 24", width: 14, height: 14, aria: { hidden: true }) do
      safe_join([
        tag.path(d: "M5.5 3.5h9l4 4v13h-13z", fill: filled ? "currentColor" : "none", stroke: "currentColor", "stroke-width": 1.8, "stroke-linejoin": "round"),
        tag.path(d: "M8.5 11.5h7M8.5 15h5", stroke: filled ? "var(--panel)" : "currentColor", "stroke-width": 1.6, "stroke-linecap": "round")
      ])
    end
  end

  def bookmark_icon(filled: false)
    tag.svg(class: "bookmark-icon", viewBox: "0 0 24 24", width: 14, height: 14, aria: { hidden: true }) do
      tag.path(d: "M6.5 3.5h11a1 1 0 0 1 1 1v16l-6.5-4-6.5 4v-16a1 1 0 0 1 1-1z",
        fill: filled ? "currentColor" : "none", stroke: "currentColor", "stroke-width": 1.8, "stroke-linejoin": "round")
    end
  end

  def message_dom_classes(message)
    [ "msg", "kind-#{message.kind}", ("sidechain" if message.sidechain) ].compact.join(" ")
  end
end
