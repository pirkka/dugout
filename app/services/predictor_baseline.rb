class PredictorBaseline
  PRIOR = 5.0
  CLAMP = [ 0.05, 0.95 ].freeze
  PROB_CLAMP = [ 0.02, 0.98 ].freeze
  H2H_BASE_WEIGHT = 1.5
  H2H_FULL_AT = 3.0

  def initialize(team_records:, h2h_records:)
    @team_records = team_records
    @h2h_records = h2h_records
  end

  # Returns the starting "home win share" slider value for a fixture.
  # 0.5 means even/draw-centric, > 0.5 favors home, < 0.5 favors away.
  def value(home_id, away_id)
    diff = base_logit(home_id) - base_logit(away_id)
    pair = @h2h_records[[ home_id, away_id ].minmax]
    diff += h2h_logit(pair, home_id) if pair
    v = 1.0 / (1.0 + Math.exp(-diff))
    v.clamp(CLAMP[0], CLAMP[1]).round(2)
  end

  private

  def base_logit(team_id)
    rec = @team_records[team_id] || { matches: 0, wins: 0, draws: 0 }
    p = (rec[:wins] + 0.5 * rec[:draws] + 0.5 * PRIOR) / (rec[:matches] + PRIOR)
    logit(p.clamp(PROB_CLAMP[0], PROB_CLAMP[1]))
  end

  def h2h_logit(pair, home_id)
    n = pair[:matches].to_f
    return 0.0 if n.zero?
    home_wins = pair[:wins_by][home_id] || 0
    draws = pair[:draws]
    p = (home_wins + 0.5 * draws) / n
    weight = H2H_BASE_WEIGHT * [ 1.0, n / H2H_FULL_AT ].min
    logit(p.clamp(PROB_CLAMP[0], PROB_CLAMP[1])) * weight
  end

  def logit(p)
    Math.log(p / (1 - p))
  end
end
