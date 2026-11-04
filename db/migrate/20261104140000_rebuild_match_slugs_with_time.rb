class RebuildMatchSlugsWithTime < ActiveRecord::Migration[8.1]
  def up
    Match.reset_column_information
    Match.find_each do |match|
      new_slug = match.generate_slug
      match.update_column(:slug, new_slug) if new_slug.present?
    end
  end

  def down
    Match.reset_column_information
    Match.find_each do |match|
      next if match.slug.blank?
      away = match.away_team
      home = match.home_team
      date = match.finished || match.started || match.created_at
      next if away.nil? || home.nil? || date.nil?
      match.update_column(:slug, "#{away.slug}-vs-#{home.slug}-#{date.strftime('%Y-%m-%d')}")
    end
  end
end
