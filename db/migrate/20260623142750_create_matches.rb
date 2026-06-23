class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.string :api_id
      t.json :api_data
      t.references :competition, null: false, foreign_key: true
      t.timestamps
    end
    add_index :matches, :api_id
  end
end
