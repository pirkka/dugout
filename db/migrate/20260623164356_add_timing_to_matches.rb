class AddTimingToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :started, :datetime
    add_column :matches, :finished, :datetime
    add_column :matches, :round, :integer
  end
end
