#!/usr/bin/env ruby

require 'base64'
require 'zlib'
require 'rexml/document'
require 'json'
require 'cgi'
require 'optparse'

module BBReplay
  ENCODED_TAGS = %w[
    Name CreatorGamerId MatchId Logo Id
    PartsItem LobbyId MessageData Ball GrandStand Pitch
  ].freeze

  ST = {
    "0" => "act", "1" => "move", "2" => nil, "3" => nil,
    "4" => "catch", "5" => "handoff", "6" => nil, "7" => nil,
    "8" => nil, "9" => nil, "10" => "kick", "11" => "pass"
  }.freeze

  INJURY_OUT = { "0" => "stunned", "1" => "knocked_out", "2" => "badly_hurt", "3" => "serious_injury", "4" => "death" }.freeze
  REMOVAL_ST = { "0" => "out_of_bounds", "1" => "stunned", "2" => "knocked_out", "3" => "badly_hurt", "4" => "serious_injury", "5" => "death" }.freeze

  BLOCK_OUTCOME_LABELS = {
    "0" => "attacker_down", "1" => "both_down", "2" => "push",
    "3" => "defender_stumble", "4" => "defender_down", "5" => "defender_push",
    "6" => "push"
  }.freeze

  ROLL_TYPE_LABELS = {
    "1" => "dodge", "2" => "go_for_it", "3" => "block",
    "4" => "pass", "5" => "catch", "6" => "armour",
    "7" => "injury", "25" => "pickup", "26" => "kickoff"
  }.freeze

  class << self
    def process(file_path)
      doc = process_bbr_file(file_path)

      info = extract_info(doc)
      result = extract_events(doc)
      events = result["events"]
      turn_meta = result["turn_meta"]
      half_boundaries = result["half_boundaries"]

      game = build_game_hierarchy(events, turn_meta, half_boundaries)
      { "info" => info, "game" => game }
    end

    def to_xml(file_path, strip_ip: true)
      doc = process_bbr_file(file_path, strip_ip: strip_ip)
      CGI.unescapeHTML(doc.to_s)
    end

    def process_bbr_file(file_path, strip_ip: true)
      raw = File.read(file_path, encoding: 'UTF-8')
      compressed = Base64.decode64(raw.strip)
      xml_string = Zlib::Inflate.inflate(compressed)
      xml_string = xml_string.force_encoding('UTF-8')
      xml_string.sub!(/encoding\s*=\s*['"](?:utf-16|utf-8|utf-16le|utf-16be)['"]/i, %q(encoding='UTF-8'))
      doc = REXML::Document.new(xml_string)

      ips = []

      walk_elements(doc.root) do |elem|
        name = elem.name

        if ENCODED_TAGS.include?(name)
          text = elem.get_text&.value&.strip
          if text && !text.empty?
            clean = text.gsub(/\s+/, '')
            if clean.match?(/\A[A-Za-z0-9+\/=]*\z/)
              decoded = Base64.decode64(clean).force_encoding('UTF-8')
              if decoded.valid_encoding? && !decoded.empty?
                elem.text = decoded
              end
            end
          end
        end

        if name == 'MessageData'
          text = elem.get_text&.value
          if text && !text.empty?
            elem.text = CGI.unescapeHTML(text)
          end
        elsif name == 'Name'
          text = elem.get_text&.value
          if text && !text.empty?
            elem.text = CGI.unescapeHTML(text)
          end
        end

        ips << elem if name == 'IpAddress'
      end

      if strip_ip
        ips.each { |ip| ip.parent&.delete_element(ip) }
      end

      doc
    end

    private

    def walk_elements(element, &block)
      block.call(element)
      element.each_element { |child| walk_elements(child, &block) }
    end

    def get_text(elem, path)
      target = elem
      path.split("/").each do |part|
        target = target.elements[part]
        return nil unless target
      end
      target.text&.strip
    rescue
      nil
    end

    def extract_info(doc)
      info = { "teams" => {}, "players" => {} }

      rosters = doc.root.elements["Rosters"]
      if rosters
        rosters.each_element("TeamRoster") do |team_roster|
          team_roster.each_element("Players/PlayerData") do |player|
            pid = player.elements["Id"]&.text&.strip
            pname = player.elements["Name"]&.text&.strip
            pnum = player.elements["Number"]&.text&.strip
            ptype = player.elements["IdPlayerTypes"]&.text&.strip
            ptid = player.elements["TeamId"]&.text&.strip

            next unless pid && !pid.empty?

            info["players"][pid] = { "name" => pname }
            info["players"][pid]["number"] = pnum.to_i if pnum
            info["players"][pid]["player_type"] = ptype.to_i if ptype
            info["players"][pid]["team"] = ptid if ptid
          end
        end
      end

      ngj = doc.root.elements["NotificationGameJoined"]
      if ngj
        ngj.each_element("GameInfos/GamersInfos/GamerInfos") do |gamer|
          slot = gamer.elements["Slot"]&.text&.strip
          coach_name = gamer.elements["Name"]&.text&.strip
          roster = gamer.elements["Roster"]
          if roster && slot
            team_name = roster.elements["Name"]&.text&.strip
            team_race = roster.elements["Team/IdRace"]&.text&.strip
            team_id = slot
            info["teams"][team_id] = { "coach_name" => coach_name }
            info["teams"][team_id]["name"] = team_name if team_name
            info["teams"][team_id]["race"] = team_race.to_i if team_race
          end
        end
      end

      end_game = doc.root.elements["EndGame"]
      if end_game
        end_game.each_element("RulesEventGameFinished/MatchResult/GamerResults/GamerResult") do |gr|
          gr.each_element("TeamResult") do |tr|
            score = tr.elements["Score"]&.text&.strip
            team_id_elem = tr.elements["TeamData/TeamId"]
            team_id = team_id_elem&.text&.strip
            next if team_id.nil? || team_id.empty? || score.nil? || score.empty?
            info["teams"][team_id] ||= {}
            info["teams"][team_id]["score"] = score.to_i
          end
        end
      end

      info
    end

    def parse_xml_text(text)
      return nil unless text && !text.empty?
      REXML::Document.new(text).root
    rescue
      decoded = Base64.decode64(text.gsub(/\s+/, '')).force_encoding('UTF-8')
      return nil unless decoded.valid_encoding?
      REXML::Document.new(decoded).root
    rescue
      nil
    end

    def extract_events(doc)
      events = []
      turn_team = nil
      turn_number = 0
      idx = 0
      player_moves = {}

      turns_per_period = 8
      walk_elements(doc.root) do |elem|
        if elem.name == "TurnsPerPeriod"
          val = elem.text&.strip&.to_i
          turns_per_period = val if val && val > 0
          break
        end
      end

      regular_counts = {}
      next_turn_is_free = false
      half_number = 0
      half_boundaries = []
      turn_meta = {}

      doc.root.each_element("ReplayStep") do |step_elem|
        step_events = []

        blitz_elem = step_elem.elements["EventBlitz"]
        quick_snap_elem = step_elem.elements["EventQuickSnap"]
        if blitz_elem || quick_snap_elem
          next_turn_is_free = true
        end

        # EventTouchdown
        td_elem = step_elem.elements["EventTouchdown"]
        if td_elem
          td_player = td_elem.elements["PlayerId"]&.text&.strip
          step_events << { "type" => "touchdown", "player" => td_player } if td_player
        end

        # EventFaceUpStunnedPlayers
        fup = step_elem.elements["EventFaceUpStunnedPlayers/Players"]
        if fup
          fup.each_element("PlayersItem") do |pi|
            pid = pi.text&.strip
            step_events << { "type" => "stunned", "player" => pid } if pid
          end
        end

        # EventActiveGamerChanged + EventEndTurn (turn tracking)
        agc = step_elem.elements["EventActiveGamerChanged"]
        had_endturn = !step_elem.elements["EventEndTurn"].nil?

        if agc && had_endturn
          ng = agc.elements["NewActiveGamer"]&.text&.strip
          turn_team = ng if ng && !ng.empty?
          if ng && !ng.empty?
            team = ng
          else
            team = "0"
          end
          turn_number += 1

          is_free = next_turn_is_free
          next_turn_is_free = false

          turn_meta[turn_number] = { "team" => team, "is_free" => is_free }

          if !is_free
            regular_counts[team] = (regular_counts[team] || 0) + 1
          end

          half_number = 1 if half_number == 0

          if half_boundaries.size < 2 &&
             regular_counts.values.min && regular_counts.values.min >= turns_per_period
            half_boundaries << turn_number
            regular_counts = {}
            half_number = 2
          end

          step_events << { "type" => "turn", "team" => team, "number" => turn_number }
        elsif had_endturn
          turn_number += 1
          team = turn_team || "0"
          is_free = next_turn_is_free
          next_turn_is_free = false

          turn_meta[turn_number] = { "team" => team, "is_free" => is_free }

          if !is_free
            regular_counts[team] = (regular_counts[team] || 0) + 1
          end

          half_number = 1 if half_number == 0

          if half_boundaries.size < 2 &&
             regular_counts.values.min && regular_counts.values.min >= turns_per_period
            half_boundaries << turn_number
            regular_counts = {}
            half_number = 2
          end

          step_events << { "type" => "turn", "team" => team, "number" => turn_number }
        elsif agc
          ng = agc.elements["NewActiveGamer"]&.text&.strip
          turn_team = ng if ng && !ng.empty?
        end

        # Emit events collected so far (stunned, turn, touchdown) before potentially skipping
        step_events.each do |ev|
          ev["index"] = idx
          idx += 1
        end
        events.concat(step_events)
        step_events = []

        step_result = step_elem.elements["EventExecuteSequence/Sequence/StepResult"]
        next unless step_result

        step = step_result.elements["Step"]
        next unless step

        step_name = step.elements["Name"]&.text&.strip
        step_data_text = step.elements["MessageData"]&.text&.strip
        sroot = parse_xml_text(step_data_text)

        player_id = sroot&.elements["PlayerId"]&.text&.strip
        target_id = sroot&.elements["TargetId"]&.text&.strip
        step_type = sroot&.elements["StepType"]&.text&.strip

        cfx = sroot&.elements["CellFrom/X"]&.text&.strip
        cfy = sroot&.elements["CellFrom/Y"]&.text&.strip
        ctx = sroot&.elements["CellTo/X"]&.text&.strip
        cty = sroot&.elements["CellTo/Y"]&.text&.strip
        cell_from = [cfx, cfy].join(",") if cfx && cfy
        cell_to = [ctx, cty].join(",") if ctx && cty

        if player_id && cell_from && cell_to
          mp = player_moves[player_id]
          if mp.nil?
            player_moves[player_id] = [cell_from, cell_to]
          elsif mp.last == cell_from
            player_moves[player_id] << cell_to
          else
            player_moves[player_id] = [cell_from, cell_to]
          end
        end

        results_elem = step_result.elements["Results"]
        next unless results_elem

        results_elem.each_element("StringMessage") do |sm|
          rname = sm.elements["Name"]&.text&.strip
          rdata = parse_xml_text(sm.elements["MessageData"]&.text&.strip)
          next unless rname && rdata

          case rname
          when "ResultBlockOutcome"
            a = rdata.elements["AttackerId"]&.text&.strip
            d = rdata.elements["DefenderId"]&.text&.strip
            o = rdata.elements["Outcome"]&.text&.strip
            if a && d && o
              step_events << { "type" => "block", "player" => a, "target" => d, "outcome" => (BLOCK_OUTCOME_LABELS[o] || "outcome_#{o}") }
            end

          when "ResultMoveOutcome"
            moved = rdata.elements["Moved"]&.text&.strip
            if moved == "1"
              ev = { "type" => "move", "player" => player_id }
              path = player_moves.delete(player_id)
              if path && path.size >= 2
                ev["from"] = path.first
                ev["path"] = path
                ev["to"] = path.last
              else
                ev["from"] = cell_from if cell_from
                ev["to"] = cell_to if cell_to
              end
              step_events << ev
            end

          when "ResultRoll"
            status = rdata.elements["Status"]&.text&.strip
            rt = rdata.elements["RollType"]&.text&.strip
            outcome = rdata.elements["Outcome"]&.text&.strip
            ok = status == "1"

            if rt == "7"
              outcome_label = INJURY_OUT[outcome] || outcome
              step_events << { "type" => "injury", "player" => player_id, "target" => target_id, "outcome" => outcome_label }
            elsif rt == "6"
              step_events << { "type" => "armour", "player" => player_id, "target" => target_id, "success" => ok }
            elsif step_name == "DamageStep"
              step_events << { "type" => "armour", "player" => player_id, "target" => target_id, "success" => ok } if ok
            elsif step_type == "11"
              step_events << { "type" => "pass", "player" => player_id, "target" => target_id, "success" => ok }
            elsif step_type == "4"
              step_events << { "type" => "catch", "player" => player_id, "target" => target_id, "success" => ok }
            elsif step_type == "5"
              step_events << { "type" => "handoff", "player" => player_id, "target" => target_id, "success" => ok }
            elsif rt && ROLL_TYPE_LABELS[rt] && player_id
              rtype = ROLL_TYPE_LABELS[rt]
              if rtype == "pickup"
                step_events << { "type" => "pickup", "player" => player_id, "success" => ok }
              elsif rtype == "dodge" || rtype == "go_for_it"
                step_events << { "type" => rtype, "player" => player_id, "success" => ok }
              end
            end

          when "ResultUseAction"
            action = rdata.elements["Action"]&.text&.strip
            step_events << { "type" => "foul", "player" => player_id, "target" => target_id } if action == "5"

          when "ResultInjuryRoll"
            outcome = rdata.elements["Outcome"]&.text&.strip
            step_events << { "type" => "injury", "player" => player_id, "target" => target_id, "outcome" => (INJURY_OUT[outcome] || outcome) } if outcome

          when "ResultCasualtyRoll"
            step_events << { "type" => "casualty", "player" => player_id, "target" => target_id }

          when "ResultPlayerRemoval"
            pid = rdata.elements["PlayerId"]&.text&.strip
            ps = rdata.elements["Status"]&.text&.strip
            step_events << { "type" => "removal", "player" => pid, "outcome" => (REMOVAL_ST[ps] || ps) }

          when "ResultPlayerSentOff"
            pid = rdata.elements["PlayerId"]&.text&.strip
            step_events << { "type" => "sent_off", "player" => pid }

          when "ResultTeamRerollUsage"
            used = rdata.elements["Used"]&.text&.strip
            if used == "1"
              gid = rdata.elements["GamerId"]&.text&.strip
              step_events << { "type" => "reroll", "player" => (gid || player_id) }
            end

          when "ResultSkillUsage"
            pid = rdata.elements["PlayerId"]&.text&.strip
            skill = rdata.elements["Skill"]&.text&.strip
            step_events << { "type" => "skill", "player" => pid, "skill" => skill } if pid && skill
          end
        end

        step_events.each do |ev|
          ev["index"] = idx
          idx += 1
        end

        events.concat(step_events)
      end

      {
        "events" => events,
        "turn_meta" => turn_meta,
        "half_boundaries" => half_boundaries,
        "turns_per_period" => turns_per_period
      }
    end

    def build_game_hierarchy(events, turn_meta, half_boundaries)
      game = { "halves" => [] }

      return game if events.empty?

      turn_nums = []
      events_by_turn = {}
      current_tt = []
      current_turn_num = nil
      turn_teams = {}

      events.each do |ev|
        if ev["type"] == "turn"
          if current_turn_num
            events_by_turn[current_turn_num] = current_tt
          end
          current_turn_num = ev["number"]
          turn_nums << current_turn_num
          turn_teams[current_turn_num] = ev["team"]
          current_tt = []
        elsif current_turn_num
          current_tt << ev
        end
      end
      if current_turn_num
        events_by_turn[current_turn_num] = current_tt
      end

      return game if turn_nums.empty?

      if half_boundaries.empty?
        all_turns = turn_nums.map do |n|
          { "team" => turn_teams[n], "events" => events_by_turn[n] || [] }
        end
        half = { "half_number" => 1, "turns" => build_turns_from_team_turns(all_turns) }
        game["halves"] << half
        return game
      end

      prev_boundary = 0
      half_boundaries.first(2).each_with_index do |boundary, hi|
        half_turn_nums = turn_nums.select { |n| n > prev_boundary && n <= boundary }
        half = { "half_number" => hi + 1, "turns" => [] }

        team_turns = half_turn_nums.map do |n|
          { "team" => turn_teams[n], "events" => events_by_turn[n] || [] }
        end

        half["turns"] = build_turns_from_team_turns(team_turns)
        game["halves"] << half
        prev_boundary = boundary
      end

      remaining = turn_nums.select { |n| n > prev_boundary }
      if remaining.any?
        if game["halves"].size < 2
          half = { "half_number" => game["halves"].size + 1, "turns" => [] }
          team_turns = remaining.map do |n|
            { "team" => turn_teams[n], "events" => events_by_turn[n] || [] }
          end
          half["turns"] = build_turns_from_team_turns(team_turns)
          game["halves"] << half
        else
          append_to_half(game["halves"].last, remaining, turn_teams, events_by_turn)
        end
      end

      game
    end

    def build_turns_from_team_turns(team_turns)
      turns = []
      i = 0
      while i < team_turns.size
        turn_num = turns.size + 1
        turn_entry = { "turn_number" => turn_num, "team_turns" => [team_turns[i]] }
        if i + 1 < team_turns.size && team_turns[i]["team"] != team_turns[i + 1]["team"]
          turn_entry["team_turns"] << team_turns[i + 1]
          i += 2
        else
          i += 1
        end
        turns << turn_entry
      end
      turns
    end

    def append_to_half(half, turn_nums, turn_teams, events_by_turn)
      team_turns = turn_nums.map do |n|
        { "team" => turn_teams[n], "events" => events_by_turn[n] || [] }
      end

      extra_turns = build_turns_from_team_turns(team_turns)
      extra_turns.each do |t|
        t["turn_number"] = half["turns"].size + 1
        half["turns"] << t
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = { format: 'events', strip_ip: true, output: nil }

  OptionParser.new do |opts|
    opts.banner = 'Usage: ruby bbr_processor.rb <input.bbr> [options]'

    opts.on('-x', '--xml', 'Output as decoded XML') do
      options[:format] = 'xml'
    end

    opts.on('-j', '--json', 'Alias for default (compact JSON)') do
      options[:format] = 'events'
    end

    opts.on('-o', '--output FILE', 'Write output to FILE') do |f|
      options[:output] = f
    end

    opts.on('--keep-ip', 'Keep IpAddress elements (XML mode only)') do
      options[:strip_ip] = false
    end

    opts.on('-h', '--help', 'Show help') do
      puts opts
      exit
    end
  end.parse!

  if ARGV.empty?
    puts 'Error: No input file specified'
    puts 'Usage: ruby bbr_processor.rb <input.bbr> [options]'
    exit 1
  end

  input_file = ARGV[0]

  begin
    output = case options[:format]
             when 'xml'
               BBReplay.to_xml(input_file, strip_ip: options[:strip_ip])
             else
               JSON.pretty_generate(BBReplay.process(input_file))
             end

    if options[:output]
      File.write(options[:output], output)
      $stderr.puts "Written #{output.bytesize} bytes to #{options[:output]}"
    else
      puts output
    end
  rescue => e
    $stderr.puts "Error: #{e.message}"
    $stderr.puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
    exit 1
  end
end
