namespace :players do
  desc "Rebuild player versions and statuses from stored replay JSON"
  task backfill: :environment do
    count = Match.rebuild_all_versions!
    puts "Rebuilt #{count} player version(s) total"
  end

  desc "Recompute lifecycle status for all players"
  task recompute_statuses: :environment do
    count = 0
    Player.find_each do |player|
      count += 1 if player.refresh_status!
    end
    puts "Recomputed status for #{count} player(s)"
  end
end
