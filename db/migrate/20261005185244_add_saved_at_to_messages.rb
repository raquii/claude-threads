class AddSavedAtToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :saved_at, :datetime
    add_index :messages, :saved_at, where: "saved_at IS NOT NULL"
  end
end
