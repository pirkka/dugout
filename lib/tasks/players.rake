namespace :players do
  desc "Rebuild match players and statuses from stored replay JSON"
  task backfill: :environment do
    count = Match.rebuild_all_match_players!
    puts "Rebuilt #{count} match player(s) total"
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
