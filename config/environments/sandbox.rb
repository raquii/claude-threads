# Development, pointed at the sample sessions in test/fixtures and its own databases.
# Use it to try changes without touching your real conversations: bin/sandbox
require_relative "development"

Rails.application.configure do
  config.x.projects_root = Rails.root.join("test/fixtures/files/claude/projects").to_s

  # Propshaft only serves assets live in development and test; without this the sandbox has no CSS or JS.
  config.assets.server = true
  config.assets.sweep_cache = true
  config.importmap.sweep_cache = true
end
