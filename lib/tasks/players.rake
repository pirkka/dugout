namespace :players do
  desc "Backfill player versions from stored replay JSON"
  task backfill: :environment do
    total = 0
    Match.where.not(replay_json: nil).find_each do |match|
      count = match.record_player_versions!
      puts "Match #{match.api_id}: #{count} player version(s)"
      total += count
    end
    puts "Created #{total} player version(s) total"
  end
end
