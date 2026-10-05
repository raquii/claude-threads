# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_06_150100) do
  create_table "conversations", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "session_uuid", null: false
    t.string "custom_name"
    t.string "agent_name"
    t.string "ai_title"
    t.text "first_prompt"
    t.string "cwd"
    t.string "git_branch"
    t.string "continued_in_session_uuid"
    t.integer "message_count", default: 0, null: false
    t.datetime "last_activity_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "favorited_at"
    t.string "last_model"
    t.string "last_effort"
    t.string "last_permission_mode"
    t.index ["project_id", "last_activity_at"], name: "index_conversations_on_project_id_and_last_activity_at"
    t.index ["project_id"], name: "index_conversations_on_project_id"
    t.index ["session_uuid"], name: "index_conversations_on_session_uuid", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.integer "transcript_id", null: false
    t.string "kind", null: false
    t.string "uuid"
    t.boolean "sidechain", default: false, null: false
    t.text "body"
    t.string "tool_name"
    t.string "tool_use_id"
    t.text "tool_input"
    t.string "media_type"
    t.boolean "is_error", default: false, null: false
    t.string "model"
    t.datetime "sent_at"
    t.datetime "saved_at"
    t.index ["conversation_id", "tool_use_id"], name: "index_messages_on_conversation_id_and_tool_use_id"
    t.index ["saved_at"], name: "index_messages_on_saved_at", where: "saved_at IS NOT NULL"
    t.index ["transcript_id", "id"], name: "index_messages_on_transcript_id_and_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "dir_name", null: false
    t.string "cwd"
    t.datetime "last_activity_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dir_name"], name: "index_projects_on_dir_name", unique: true
  end

  create_table "runs", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.text "prompt", null: false
    t.string "permission_mode", null: false
    t.string "status", default: "queued", null: false
    t.integer "pid"
    t.integer "exit_status"
    t.text "error"
    t.text "denied_tools"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "model"
    t.string "effort"
    t.index ["conversation_id"], name: "index_runs_on_conversation_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "projects_root", null: false
    t.string "claude_path", default: "claude", null: false
    t.integer "scan_interval_seconds", default: 60, null: false
    t.datetime "last_scanned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "appearance", default: "system", null: false
    t.string "theme", default: "clay", null: false
    t.string "font", default: "system", null: false
    t.string "editor", default: "vscode", null: false
  end

  create_table "transcripts", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.string "path", null: false
    t.string "agent_id"
    t.string "agent_type"
    t.string "description"
    t.string "tool_use_id"
    t.integer "byte_offset", default: 0, null: false
    t.integer "file_size", default: 0, null: false
    t.datetime "file_mtime"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "generation", default: 0, null: false
    t.json "carried_saves"
    t.index ["conversation_id", "tool_use_id"], name: "index_transcripts_on_conversation_id_and_tool_use_id"
    t.index ["conversation_id"], name: "index_transcripts_on_conversation_id"
    t.index ["path"], name: "index_transcripts_on_path", unique: true
  end

  add_foreign_key "conversations", "projects"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "transcripts"
  add_foreign_key "runs", "conversations"
  add_foreign_key "transcripts", "conversations"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "messages_fts", "fts5", ["body", "tokenize='porter unicode61'"]
end
