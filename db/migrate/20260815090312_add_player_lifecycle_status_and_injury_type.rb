class AddPlayerLifecycleStatusAndInjuryType < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :status, :string, null: false, default: "active"
    add_index :players, :status

    add_column :player_versions, :injury_type, :string
  end
end
