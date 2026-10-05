class AddEditorToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :editor, :string, null: false, default: "vscode"
  end
end
