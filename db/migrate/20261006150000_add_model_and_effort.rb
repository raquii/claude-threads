class AddModelAndEffort < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :last_model, :string
    add_column :conversations, :last_effort, :string
    add_column :conversations, :last_permission_mode, :string
    add_column :runs, :model, :string
    add_column :runs, :effort, :string
  end
end
