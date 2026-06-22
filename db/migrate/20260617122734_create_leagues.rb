class CreateLeagues < ActiveRecord::Migration[8.1]
  def change
    create_table :leagues do |t|
      t.timestamps
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :platform, null: false
    end
  end
end
