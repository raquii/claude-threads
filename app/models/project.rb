class Project < ApplicationRecord
  has_many :conversations, dependent: :destroy

  def name
    cwd.present? ? cwd.sub(Dir.home, "~") : dir_name
  end
end
