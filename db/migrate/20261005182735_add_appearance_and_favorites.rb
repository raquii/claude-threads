class AddAppearanceAndFavorites < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :appearance, :string, null: false, default: "system"
    add_column :settings, :theme, :string, null: false, default: "clay"
    add_column :settings, :font, :string, null: false, default: "system"
    add_column :conversations, :favorited_at, :datetime
  end
end
