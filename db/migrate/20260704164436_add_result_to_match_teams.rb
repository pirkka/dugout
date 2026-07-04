class AddResultToMatchTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :match_teams, :result, :integer
  end
end
