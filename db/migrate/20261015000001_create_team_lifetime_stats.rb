class CreateTeamLifetimeStats < ActiveRecord::Migration[8.1]
  def change
    create_table :team_lifetime_stats do |t|
      t.references :team, null: false, foreign_key: true, index: { unique: true }
      t.integer :matches, default: 0, null: false
      t.integer :wins, default: 0, null: false
      t.integer :draws, default: 0, null: false
      t.integer :losses, default: 0, null: false
      t.integer :points, default: 0, null: false
      t.integer :touchdowns_made, default: 0, null: false
      t.integer :touchdowns_sustained, default: 0, null: false
      t.integer :casualties_made, default: 0, null: false
      t.integer :casualties_sustained, default: 0, null: false

      t.timestamps
    end
  end
end
