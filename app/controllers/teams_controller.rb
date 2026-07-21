class TeamsController < ApplicationController
  before_action :set_team, only: %i[show refresh]

  def show
    if @team.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @team.competitions.first&.league
      @competition = @team.competitions.first
    end
  end

  def refresh
    if @team.nil?
      redirect_to root_path, alert: "Team not found"
    elsif @team.refresh
      redirect_back fallback_location: @team, notice: "Team refreshed"
    else
      redirect_back fallback_location: @team, alert: @team.errors.full_messages.join(", ")
    end
  end

  private

  def set_team
    @team = Team.includes(:competitions, matches: { match_teams: :team }).find_by(slug: params[:slug])
  end
end
