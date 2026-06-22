class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.timestamps
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :value
      t.integer :cash
      t.datetime :inception, null: false
      t.integer :cheerleaders
      t.integer :assistant_coaches
      t.integer :popularity
      t.integer :rerolls
      t.integer :apothecary
      t.string :logo
      t.integer :coach_id
    end
  end
end
