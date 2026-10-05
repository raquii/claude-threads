class CreateMessagesFts < ActiveRecord::Migration[8.1]
  def up
    create_virtual_table :messages_fts, :fts5, [ "body", "tokenize='porter unicode61'" ]
    execute <<~SQL
      INSERT INTO messages_fts (rowid, body)
      SELECT id, body FROM messages WHERE kind IN ('prompt', 'text') AND body IS NOT NULL
    SQL
  end

  def down
    drop_virtual_table :messages_fts, :fts5, [ "body", "tokenize='porter unicode61'" ]
  end
end
