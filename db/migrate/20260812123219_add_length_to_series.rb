class AddLengthToSeries < ActiveRecord::Migration[8.1]
  def change
    add_column :series, :length, :integer
  end
end
