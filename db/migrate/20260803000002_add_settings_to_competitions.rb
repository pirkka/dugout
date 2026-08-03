class AddSettingsToCompetitions < ActiveRecord::Migration[8.1]
  def change
    add_column :competitions, :settings, :json, default: {}
  end
end
