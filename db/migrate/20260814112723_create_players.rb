class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :number
      t.string :name, null: false

      t.timestamps
    end

    add_index :players, [:team_id, :number], unique: true
  end
end
