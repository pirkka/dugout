class AddHomeToMatchTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :match_teams, :home, :boolean
  end
end
