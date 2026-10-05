# Claude Threads

A local web app for reading your Claude Code sessions as chat threads. It imports the transcripts Claude Code keeps in `~/.claude/projects`, groups them by project, and lets you search, favorite, save, and continue them from the browser.

Everything stays on your machine. The app copies your sessions into a SQLite database under `storage/`, which git ignores.

## Requirements

| | |
|---|---|
| OS | macOS. Linux works except for the editor links, which depend on your editor's URL handler. |
| Ruby | 4.0.6 (see `.ruby-version`), with Bundler |
| Claude Code | Installed and signed in, for continuing sessions from the app. Reading sessions works without it. |

## Setup

```sh
git clone <this repo> claude-threads
cd claude-threads
bundle install
bin/rails db:prepare
bin/dev
```

Open http://localhost:3000. The first scan starts within 10 seconds and imports every session in `~/.claude/projects`; **Scan now** in the sidebar starts one immediately. A large history takes a few seconds per hundred megabytes.

`bin/dev` runs the web server and the background scanner in one process. Leave it running while you use the app.

## Using it

| Feature | How |
|---|---|
| Rename a conversation | The ✎ next to its title. Without a name, the title comes from `/rename`, then Claude's generated title, then your first prompt. |
| Favorite | The ☆ next to the title, or on a sidebar row when you hover. Favorites move to the top of the sidebar. |
| Save a message | Hover over a prompt or reply and click the bookmark. **Saved** at the top of the sidebar lists them. |
| Archive | **Archive** in the conversation header. Archived conversations collect at the bottom of the sidebar. |
| Search | The box at the top of the sidebar searches conversation titles and the text of your prompts and Claude's replies. Results link to the message. |
| Show more detail | **Tool calls** (with **Thinking** and **Subagents** inside it) and **System** in the header. Your choices are remembered. |
| Open a file Claude mentions | Click the file link. It opens in your editor at that line. Choose the editor in Settings. |

### Continuing a session

The box at the bottom of a conversation sends a new message to that session. The app runs `claude -p --resume <session>` in the session's original directory, and the reply appears as Claude Code writes it.

| Permission mode | Effect |
|---|---|
| Ask (blocked tools fail) | Tools that need approval are refused. The app lists what was blocked so you can resend. |
| Accept edits | File edits are allowed. Other tools that need approval are refused. |
| Plan only | Claude plans without making changes. |
| Bypass all | Every tool runs without approval. |

The app won't send to a session that is open in a terminal or running in the background, because both processes would write to the same history. Close the other one first. Sessions whose directory no longer exists can be read but not continued.

## Settings

**Settings** (top of the sidebar) controls the color scheme, light or dark mode, typeface, which editor opens file links, how often the scanner runs, the folder it reads, and the `claude` executable it uses.

## Privacy

| Data | Where it lives | In git |
|---|---|---|
| Your conversations | `storage/development.sqlite3` | Ignored |
| Logs, which include conversation text | `log/` | Ignored |
| Rendered-page cache | memory, and `tmp/` | Ignored |

Nothing is sent anywhere except the messages you send to Claude through **Continue this session**, which go through your own `claude` CLI.

## Development

| Command | Purpose |
|---|---|
| `bin/rails test` | Runs the tests against `storage/test.sqlite3` and the sample sessions in `test/fixtures/files/claude`. |
| `bin/sandbox` | Runs the app on http://localhost:3001 against the sample sessions, with its own databases. It rebuilds them on every start. Use it to try changes without touching your own conversations. |

The importer reads only the lines appended since its last pass, so rescans are cheap. Conversations stay in the database after Claude Code deletes old transcripts from disk; they can still be read, but not continued.
