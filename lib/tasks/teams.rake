namespace :teams do
  namespace :lifetime do
    desc "Rebuild cached lifetime stats for all teams from match data"
    task rebuild_all: :environment do
      count = 0
      Team.find_each do |team|
        team.recalculate_lifetime_stats!
        count += 1
      end
      puts "Rebuilt lifetime stats for #{count} team(s)"
    end
  end
end
