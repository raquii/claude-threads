class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :conversation, null: false, foreign_key: true, index: false
      t.string :message_uuid
      t.text :body, null: false
      t.timestamps
    end
    add_index :notes, [ :conversation_id, :message_uuid ], unique: true
    add_index :notes, :conversation_id, unique: true, where: "message_uuid IS NULL", name: "index_notes_one_conversation_note"
  end
end
