class AddSlugToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :slug, :string
    add_index :matches, :slug
  end
end
