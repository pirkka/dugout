class AddSloganToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :slogan, :string
  end
end
