class AddMatchHashToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :match_hash, :string
  end
end
