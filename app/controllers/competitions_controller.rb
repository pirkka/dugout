class CompetitionsController < ApplicationController
  def show
    @competition = Competition.includes(:league, :teams, :competition_teams, matches: { match_teams: :team }).find_by(slug: params[:slug])
    if @competition.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @competition.league
    end
  end

  def refresh
    @competition = Competition.find_by(slug: params[:slug])
    if @competition.nil?
      redirect_to root_path, alert: "Competition not found"
    elsif @competition.refresh_teams && @competition.refresh_matches
      redirect_back fallback_location: @competition, notice: "Competition refreshed"
    else
      redirect_back fallback_location: @competition, alert: "Refresh failed"
    end
  end
end
