class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :projects_root, null: false
      t.string :claude_path, null: false, default: "claude"
      t.integer :scan_interval_seconds, null: false, default: 60
      t.datetime :last_scanned_at
      t.timestamps
    end

    create_table :projects do |t|
      t.string :dir_name, null: false, index: { unique: true }
      t.string :cwd
      t.datetime :last_activity_at
      t.timestamps
    end

    create_table :conversations do |t|
      t.references :project, null: false, foreign_key: true
      t.string :session_uuid, null: false, index: { unique: true }
      t.string :custom_name
      t.string :agent_name
      t.string :ai_title
      t.text :first_prompt
      t.string :cwd
      t.string :git_branch
      t.string :continued_in_session_uuid
      t.integer :message_count, null: false, default: 0
      t.datetime :last_activity_at
      t.datetime :archived_at
      t.timestamps
    end
    add_index :conversations, [ :project_id, :last_activity_at ]

    create_table :transcripts do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :path, null: false, index: { unique: true }
      t.string :agent_id
      t.string :agent_type
      t.string :description
      t.string :tool_use_id
      t.integer :byte_offset, null: false, default: 0
      t.integer :file_size, null: false, default: 0
      t.datetime :file_mtime
      t.timestamps
    end
    add_index :transcripts, [ :conversation_id, :tool_use_id ]

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true, index: false
      t.references :transcript, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.string :uuid
      t.boolean :sidechain, null: false, default: false
      t.text :body
      t.string :tool_name
      t.string :tool_use_id
      t.text :tool_input
      t.string :media_type
      t.boolean :is_error, null: false, default: false
      t.string :model
      t.datetime :sent_at
    end
    add_index :messages, [ :transcript_id, :id ]
    add_index :messages, [ :conversation_id, :tool_use_id ]

    create_table :runs do |t|
      t.references :conversation, null: false, foreign_key: true
      t.text :prompt, null: false
      t.string :permission_mode, null: false
      t.string :status, null: false, default: "queued"
      t.integer :pid
      t.integer :exit_status
      t.text :error
      t.text :denied_tools
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
