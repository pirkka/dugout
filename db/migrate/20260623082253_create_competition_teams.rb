class CreateCompetitionTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :competition_teams do |t|
      t.references :competition, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.json :api_data

      t.timestamps
    end

    add_index :competition_teams, [:competition_id, :team_id], unique: true
  end
end
