class TeamsController < ApplicationController
  def show
    @team = Team.includes(:competitions, matches: { match_teams: :team }).find_by(slug: params[:slug])
    if @team.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @team.competitions.first&.league
    end
  end
end
