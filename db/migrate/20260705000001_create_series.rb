class CreateSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :series do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :league, null: false, foreign_key: true

      t.timestamps
    end
  end
end
