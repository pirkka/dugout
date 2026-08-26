class AddInjuryDetailToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :injury_detail, :string
  end
end
