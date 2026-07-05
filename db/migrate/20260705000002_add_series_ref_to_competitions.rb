class AddSeriesRefToCompetitions < ActiveRecord::Migration[8.1]
  def change
    add_reference :competitions, :series, foreign_key: true
  end
end
