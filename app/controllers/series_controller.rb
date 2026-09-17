class SeriesController < ApplicationController
  def show
    @series = Series.includes(:league, competitions: [ { competition_teams: :team }, { matches: { match_teams: :team } }, { contests: [ :home_team, :away_team ] } ], series_teams: :team).find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @series.league
    end
  end

  def create
    league = League.find_by(slug: params[:slug])
    if league.nil?
      redirect_to root_path, alert: "League not found"
    else
      series = league.series.create!(name: params[:series_name], slug: params[:series_name].parameterize)
      redirect_to series, notice: "Series created"
    end
  end

  def edit
    @series = Series.find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end

  def update
    @series = Series.find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    elsif @series.update(series_params)
      redirect_to @series, notice: "Series updated"
    else
      flash.now[:alert] = @series.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def predictor
    @series = Series.includes(:league, competitions: { contests: [ :home_team, :away_team ] }, series_teams: :team).find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @series.league
      @upcoming = @series.competitions.flat_map(&:contests).select { |c| c.home_team || c.away_team }.sort_by { |c| c.match_date || Time.at(0) }
      @teams_json = @series.series_teams.map do |st|
        { id: st.team_id, name: st.team.name, race: st.team.race, points: st.points, wins: st.wins, tds_made: (st.touchdowns_made || 0), tds_sustained: (st.touchdowns_sustained || 0) }
      end
      @team_indices = @teams_json.each_with_index.to_h { |t, i| [ t[:id], i ] }
      @fixtures_json = @upcoming.filter_map do |c|
        home = c.home_team && @team_indices[c.home_team_id]
        away = c.away_team && @team_indices[c.away_team_id]
        next if home.nil? && away.nil?
        ai = c.home_team.nil? || c.away_team.nil?
        next if !ai && (home.nil? || away.nil?)
        { home: home, away: away, ai: ai, date: c.match_date&.to_date&.iso8601, round: c.round }
      end
    end
  end

  def refresh
    @series = Series.find_by(slug: params[:slug])
    if @series.nil?
      redirect_to root_path, alert: "Series not found"
    else
      @series.calculate_standings
      redirect_back fallback_location: @series, notice: "Standings refreshed"
    end
  end

  private

  def series_params
    params.require(:series).permit(:name, :length, :playoff_cutoff)
  end
end
