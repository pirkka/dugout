class BackfillHighlights < ActiveRecord::Migration[8.1]
  def up
    Match.where.not(replay_json: nil).find_each do |match|
      parsed = match.replay_json
      highlights_data = Array(parsed["highlights"])
      next if highlights_data.empty?

      key_map = build_key_map(match, parsed)

      highlights_data.each do |h|
        match_player = key_map[h["player_id"]&.to_s]
        injured_mp = key_map[h["injured_player_id"]&.to_s] if h["injured_player_id"]

        match.highlights.create!(
          match_player: match_player,
          injured_match_player: injured_mp,
          event: h["event"],
          turn: h["turn"],
          team: h["team"],
          to: h["to"],
          new_position: h["new_position"],
          data: h
        )
      end
    end
  end

  def down
    Highlight.delete_all
  end

  private

  def build_key_map(match, parsed)
    key_map = {}
    offset = 36

    match.match_players.each do |mp|
      side = mp.data&.dig("side")
      key = side == "away" ? (mp.number + offset).to_s : mp.number.to_s
      key_map[key] = mp
    end

    key_map
  end
end
