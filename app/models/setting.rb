class Setting < ApplicationRecord
  APPEARANCES = { "system" => "Match system", "light" => "Light", "dark" => "Dark" }.freeze
  THEMES = { "clay" => "Clay", "slate" => "Slate", "forest" => "Forest", "plum" => "Plum", "guava" => "Guava", "rose" => "Dusty rose",
    "tomorrow" => "Tomorrow", "mono" => "Graphite" }.freeze
  FONTS = {
    "system" => "San Francisco (system)",
    "avenir" => "Avenir Next",
    "helvetica" => "Helvetica Neue",
    "charter" => "Charter",
    "iowan" => "Iowan Old Style",
    "mono" => "SF Mono"
  }.freeze

  # {path} and {line} are filled in the browser when a file link is clicked.
  EDITORS = {
    "vscode" => { label: "VS Code", url: "vscode://file{path}:{line}" },
    "cursor" => { label: "Cursor", url: "cursor://file{path}:{line}" },
    "zed" => { label: "Zed", url: "zed://file{path}:{line}" },
    "idea" => { label: "JetBrains IDE", url: "idea://open?file={path}&line={line}" }
  }.freeze

  validates :scan_interval_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 10 }
  validates :projects_root, :claude_path, presence: true
  validates :appearance, inclusion: { in: APPEARANCES.keys }
  validates :theme, inclusion: { in: THEMES.keys }
  validates :font, inclusion: { in: FONTS.keys }
  validates :editor, inclusion: { in: EDITORS.keys }

  def editor_url_template
    EDITORS.fetch(editor)[:url]
  end

  def self.current
    first_or_create!(projects_root: Rails.configuration.x.projects_root || File.expand_path("~/.claude/projects"))
  end

  def scan_due?
    last_scanned_at.nil? || last_scanned_at <= scan_interval_seconds.seconds.ago
  end
end
