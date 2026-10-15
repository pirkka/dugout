class AddLiveToContests < ActiveRecord::Migration[8.1]
  def change
    add_column :contests, :live, :boolean, default: false, null: false
  end
end
