class CreateSeriesTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :series_teams do |t|
      t.references :series, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.json :api_data
      t.integer :matches
      t.integer :wins
      t.integer :losses
      t.integer :draws
      t.integer :points
      t.integer :position

      t.timestamps
    end

    add_index :series_teams, [:series_id, :team_id], unique: true
  end
end
