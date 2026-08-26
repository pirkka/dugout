require 'bbr_processor'

class Match < ApplicationRecord
  REPLAY_FILENAME_REGEX = /\A\d{4}-\d{2}-\d{2}_\d{2}-\d{2}_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.bbr\z/i
  AWAY_PLAYER_ID_OFFSET = 36
  INJURY_PRIORITY = {
    Player::DEAD => 0,
    Player::MNG => 1,
    "niggling_or_stat" => 2,
    "badly_hurt" => 3,
    "knocked_out" => 4
  }.freeze

  belongs_to :competition
  has_many :match_teams, dependent: :destroy
  has_many :teams, through: :match_teams
  has_many :match_players, dependent: :destroy

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
          match.record_match_players!(parsed)
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
    record_match_players!(parsed)
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
    record_match_players!(result)
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
     self.finished&.to_s&.split('.')&.first&.gsub(' UTC','')&.split(':')&.first] # remove trailing numbers (round to full seconds)
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

  # Rebuilds match players for this match, then reprocesses both teams'
  # remaining matches in chronological order so player identity resolution
  # stays consistent (player numbers shift over time and names change in BB3).
  def record_match_players!(parsed = replay_json)
    return 0 unless parsed.is_a?(Hash)

    transaction do
      build_match_players!(parsed)
      affected_teams(parsed).compact.each { |team| self.class.rebuild_team_match_players!(team, except: id) }
      Player.find_each(&:refresh_status!)
      match_players.count
    end
  end

  # Rebuilds every match player from stored replay JSON in chronological
  # order (match ids are not chronological) and recomputes lifecycle statuses.
  def self.rebuild_all_match_players!
    count = 0
    transaction do
      MatchPlayer.delete_all
      Player.delete_all
      Match.where.not(replay_json: nil)
        .order(Arel.sql("COALESCE(matches.started, matches.finished)"))
        .each { |match| count += match.send(:build_match_players!, match.replay_json) }
      Player.find_each(&:refresh_status!)
    end
    count
  end

  private

  def self.rebuild_team_match_players!(team, except: nil)
    team.matches.where.not(replay_json: nil)
      .where.not(id: except)
      .order(Arel.sql("COALESCE(matches.started, matches.finished)"))
      .each { |match| match.send(:build_match_players!, match.replay_json) }
  end

  def build_match_players!(parsed)
    match_players.destroy_all
    if parsed.dig("teams", "home", "players").is_a?(Hash)
      record_match_players_new_format(parsed)
    elsif parsed.dig("info", "players").is_a?(Hash)
      record_match_players_old_format(parsed)
    end
  end

  def affected_teams(parsed)
    if parsed.dig("teams", "home", "players").is_a?(Hash)
      [Team.find_by(api_id: parsed.dig("teams", "home", "id").to_s),
       Team.find_by(api_id: parsed.dig("teams", "away", "id").to_s)]
    else
      [home_team, away_team]
    end
  end

  # Maps JSON player keys to the severest injury sustained in a match. The
  # injury_caused events carry an "injured_player_id" that is the JSON player
  # key (home keys start at 1, away keys are offset by 36), so the key
  # uniquely identifies the player within a match. The event's "team" field
  # is unreliable, so we ignore it.
  def injuries_by_key(parsed)
    injuries = {}
    Array(parsed["highlights"]).each do |event|
      next unless event["event"] == "injury_caused"

      key = event["injured_player_id"].to_s
      type = event["injury_type"]
      next unless type && INJURY_PRIORITY.key?(type)

      current = injuries[key]
      if current.nil? || INJURY_PRIORITY[type] < INJURY_PRIORITY[current[:type]]
        injuries[key] = { type: type, detail: event["injury_detail"] }
      end
    end
    injuries
  end

  def record_match_players_new_format(parsed)
    count = 0
    injuries = injuries_by_key(parsed)

    parsed["teams"].each do |side, team_data|
      team = Team.find_by(api_id: team_data["id"].to_s)
      next unless team

      offset = side == "away" ? AWAY_PLAYER_ID_OFFSET : 0

      team_data["players"].each do |key, player_data|
        number = key.to_i - offset
        next unless number.positive?

        player = Player.resolve(team, number: number, name: player_data["name"])
        next unless player

        injury = injuries[key]

        match_players.create!(
          player: player,
          name: player_data["name"],
          number: number,
          kind: player_data["kind"],
          skills: player_data["skills"],
          status: player_data["status"],
          injury_type: injury&.dig(:type),
          injury_detail: injury&.dig(:detail),
          team_value: team_data["team_value"],
          format: "new",
          data: {
            "side" => side,
            "team" => { "id" => team_data["id"], "name" => team_data["name"], "team_value" => team_data["team_value"] },
            "player" => player_data
          }
        )
        count += 1
      end
    end

    count
  end

  def record_match_players_old_format(parsed)
    count = 0
    teams_by_slot = { "0" => home_team, "1" => away_team }

    parsed["info"]["players"].each do |key, player_data|
      slot = player_data["team"].to_s
      team = teams_by_slot[slot]
      next unless team

      offset = slot == "1" ? AWAY_PLAYER_ID_OFFSET : 0
      number = key.to_i - offset
      next unless number.positive?

      player = Player.resolve(team, number: number, name: player_data["name"])
      next unless player

      match_players.create!(
        player: player,
        name: player_data["name"],
        number: number,
        player_type: player_data["player_type"],
        format: "old",
        data: {
          "side" => slot == "1" ? "away" : "home",
          "team" => parsed.dig("info", "teams", slot),
          "player" => player_data
        }
      )
      count += 1
    end

    count
  end
end
