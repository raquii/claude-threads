class AddReimportTrackingToTranscripts < ActiveRecord::Migration[8.1]
  def change
    add_column :transcripts, :generation, :integer, null: false, default: 0
    add_column :transcripts, :carried_saves, :json
  end
end
