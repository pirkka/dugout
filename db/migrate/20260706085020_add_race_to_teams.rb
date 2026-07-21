class AddRaceToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :race, :string
  end
end
