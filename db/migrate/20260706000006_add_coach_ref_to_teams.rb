class AddCoachRefToTeams < ActiveRecord::Migration[8.1]
  def change
    rename_column :teams, :coach_id, :api_coach_id
    add_reference :teams, :coach, foreign_key: true
  end
end
