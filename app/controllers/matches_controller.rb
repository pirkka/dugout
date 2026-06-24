class MatchesController < ApplicationController
  def show
    @match = Match.includes(:competition, match_teams: :team).find_by(id: params[:id])
    if @match.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @match.competition.league
    end
  end
end
