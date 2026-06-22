class CreateCompetitions < ActiveRecord::Migration[8.1]
  def change
    create_table :competitions do |t|
      t.timestamps
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :league_id, null: false
      t.integer :platform, null: false
      t.integer :format, null: false
    end
  end
end
