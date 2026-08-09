require 'bbr_processor'

class Match < ApplicationRecord
  REPLAY_FILENAME_REGEX = /\A\d{4}-\d{2}-\d{2}_\d{2}-\d{2}_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.bbr\z/i

  belongs_to :competition
  has_many :match_teams, dependent: :destroy
  has_many :teams, through: :match_teams

  def home_team
    match_teams.find_by(home: true)&.team
  end

  def away_team
    match_teams.find_by(home: false)&.team
  end

  def self.upload_replay_jsons(files)
    uploaded = 0
    skipped = 0
    Array(files).each do |file|
      next unless file.respond_to?(:read)
      begin
        parsed = JSON.parse(file.read)
        match = find_by(match_hash: parsed["match_hash"])
        if match
          match.update!(replay_json: parsed)
          uploaded += 1
        else
          skipped += 1
        end
      rescue JSON::ParserError
        skipped += 1
      end
    end
    { uploaded: uploaded, skipped: skipped }
  end

  def upload_replay(file)
    return false unless file

    filename = file.original_filename

    unless filename.match?(REPLAY_FILENAME_REGEX)
      errors.add(:replay_data, "filename must be a .bbr file with format YYYY-MM-DD_HH-MM_GUID.bbr")
      return false
    end

    guid = filename.match(REPLAY_FILENAME_REGEX)&.captures&.first
    unless guid.present? && guid == api_id
      errors.add(:replay_data, "GUID in filename does not match match api_id")
      return false
    end

    update!(replay_data: file.read, replay_file_name: filename)
  end

  def replay?
    replay_data.present?
  end

  def upload_replay_json(file)
    return false unless file

    parsed = JSON.parse(file.read)
    update!(replay_json: parsed)
    true
  rescue => e
    errors.add(:replay_json, "Invalid JSON: #{e.message}")
    false
  end

  def parse_replay!
    return false unless replay_data.present?

    tmpfile = Tempfile.new(['replay', '.bbr'], encoding: 'UTF-8')
    tmpfile.write(replay_data.dup)
    tmpfile.rewind

    result = BBReplay.process(tmpfile.path)
    update!(replay_json: result)
    true
  rescue => e
    errors.add(:replay_json, "Failed to parse replay: #{e.message}")
    false
  ensure
    tmpfile&.close
    tmpfile&.unlink
  end

  def cyanide_match_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = competition.league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/match/?key=#{api_key}&match_id=#{api_id}&start=1980-01-01"
  end

  def match_hash_data
    arr = [self.competition.league.api_id,
     self.competition.api_id,
     self.round.to_s,
     self.away_team&.api_id, # fix order
     self.home_team&.api_id, # fix order
     self.finished.to_s.split('.').first.gsub(' UTC','').split(':').first] # remove trailing numbers (round to full seconds)
    arr.join(':')
  end

  def calculate_match_hash
    mh = Digest::SHA256.hexdigest(
      match_hash_data
    )
    return mh
  end

  def key_highlights
    all_highlights = []
    replay_json&.dig("highlights")&.each do |highlight|
      if highlight['event'] == "touch_down"
        all_highlights << highlight
      end
    end
    all_highlights
  end
end
