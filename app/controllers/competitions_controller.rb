class CompetitionsController < ApplicationController
  def show
    @competition = Competition.includes(:league, :teams, matches: { match_teams: :team }).find_by(slug: params[:slug])
    if @competition.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @competition.league
    end
  end
end
