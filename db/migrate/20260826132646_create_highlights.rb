class CreateHighlights < ActiveRecord::Migration[8.1]
  def change
    create_table :highlights do |t|
      t.references :match, null: false, foreign_key: true
      t.references :match_player, null: true, foreign_key: true
      t.references :injured_match_player, null: true, foreign_key: { to_table: :match_players }
      t.string :event, null: false
      t.integer :turn
      t.string :team
      t.json :to
      t.json :new_position
      t.json :data
      t.timestamps
    end

    add_index :highlights, [:match_id, :event]
  end
end
