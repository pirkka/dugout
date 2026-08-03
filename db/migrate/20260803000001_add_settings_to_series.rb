class AddSettingsToSeries < ActiveRecord::Migration[8.1]
  def change
    add_column :series, :settings, :json, default: {}
  end
end
