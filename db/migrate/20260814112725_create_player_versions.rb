class CreatePlayerVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :player_versions do |t|
      t.references :player, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.string :name
      t.integer :number
      t.string :kind
      t.json :skills
      t.string :status
      t.integer :team_value
      t.integer :player_type
      t.string :format
      t.json :data

      t.timestamps
    end

    add_index :player_versions, [:player_id, :match_id], unique: true
  end
end
