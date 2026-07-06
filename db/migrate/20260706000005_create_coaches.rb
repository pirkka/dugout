class CreateCoaches < ActiveRecord::Migration[8.1]
  def change
    create_table :coaches do |t|
      t.string :api_id
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
  end
end
