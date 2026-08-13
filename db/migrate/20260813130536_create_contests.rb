class CreateContests < ActiveRecord::Migration[8.1]
  def change
    create_table :contests do |t|
      t.references :competition, null: false, foreign_key: true
      t.string :match_id
      t.integer :round
      t.string :status
      t.datetime :match_date
      t.references :home_team, foreign_key: { to_table: :teams }
      t.references :away_team, foreign_key: { to_table: :teams }
      t.json :api_data
      t.string :api_id

      t.timestamps
      t.index :api_id
    end
  end
end
