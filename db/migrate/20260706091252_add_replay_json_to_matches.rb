class AddReplayJsonToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :replay_json, :json
  end
end
