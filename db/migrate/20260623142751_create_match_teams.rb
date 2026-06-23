class CreateMatchTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :match_teams do |t|
      t.references :match, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.integer :score
      t.integer :conceded
      t.json :api_data
      t.timestamps
    end
    add_index :match_teams, [:match_id, :team_id], unique: true
  end
end
