class AddGameVersionToLeagues < ActiveRecord::Migration[8.1]
  def change
    add_column :leagues, :game_version, :integer, null: false, default: 2
  end
end
