class Series < ApplicationRecord
  belongs_to :league
  has_many :competitions, -> {
    order(Arel.sql("(SELECT MIN(matches.started) FROM matches WHERE matches.competition_id = competitions.id) DESC NULLS LAST"))
  }, dependent: :nullify
  has_many :series_teams, -> { order(position: :asc) }, dependent: :destroy
  has_many :teams, through: :series_teams

  before_update :update_slug, if: :name_changed?

  def playoff_cutoff
    settings&.dig("playoff_cutoff")
  end

  def playoff_cutoff=(value)
    self.settings = (settings || {}).merge("playoff_cutoff" => value.presence)
  end

  def active?
    competitions.any?(&:active?)
  end

  private

  def update_slug
    self.slug = name.parameterize
  end

  public

  def calculate_standings
    rows = CompetitionTeam
      .joins(:competition)
      .where(competitions: { series_id: id })
      .group(:team_id)
      .pluck(:team_id, "SUM(matches)", "SUM(wins)", "SUM(draws)", "SUM(losses)", "SUM(points)",
             "SUM(touchdowns_made)", "SUM(touchdowns_sustained)", "SUM(casualties_made)", "SUM(casualties_sustained)")

    standings = rows.map do |team_id, matches, wins, draws, losses, points, touchdowns_made, touchdowns_sustained, casualties_made, casualties_sustained|
      { team_id: team_id, matches: matches, wins: wins, draws: draws, losses: losses, points: points,
        touchdowns_made: touchdowns_made, touchdowns_sustained: touchdowns_sustained, casualties_made: casualties_made, casualties_sustained: casualties_sustained }
    end

    standings.sort_by! { |s| [-s[:points], -s[:wins], -(s[:touchdowns_made]-s[:touchdowns_sustained])] }

    standings.each_with_index do |s, i|
      st = series_teams.find_or_initialize_by(team_id: s[:team_id])
      st.update!(
        matches: s[:matches],
        wins: s[:wins],
        draws: s[:draws],
        losses: s[:losses],
        points: s[:points],
        touchdowns_made: s[:touchdowns_made],
        touchdowns_sustained: s[:touchdowns_sustained],
        casualties_made: s[:casualties_made],
        casualties_sustained: s[:casualties_sustained],
        position: i + 1
      )
    end
  end
end
