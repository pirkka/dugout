class AddEstablishedToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :established, :datetime
  end
end
