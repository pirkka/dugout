namespace :leagues do
  desc "Refresh a league from the API — usage: rake leagues:refresh[id]"
  task :refresh, [:id] => :environment do |_, args|
    league = League.find(args[:id])
    if league.refresh_from_api
      puts "Refreshed league ##{league.id} (#{league.name})"
    else
      puts "Failed to refresh league ##{args[:id]}: #{league.errors.full_messages.join(", ")}"
      exit 1
    end
  end

  desc "Refresh all leagues from the API"
  task refresh_all: :environment do
    League.find_each do |league|
      if league.refresh_from_api
        puts "Refreshed league ##{league.id} (#{league.name})"
      else
        puts "Failed to refresh league ##{league.id} (#{league.name}): #{league.errors.full_messages.join(", ")}"
      end
    end
  end

  desc "Backfill competition statuses based on existing data"
  task backfill_statuses: :environment do
    Competition.find_each do |comp|
      old_status = comp.status
      comp.compute_status!
      if comp.status != old_status
        puts "#{comp.name}: #{old_status} -> #{comp.status}"
      end
    end
    puts "Done."
  end
end
