class MatchesController < ApplicationController
  before_action :set_match, only: %i[show upload_replay parse_replay replay]

  def show
    if @match.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end

  def replay
    if @match.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end

  def parse_replay
    if @match.nil?
      redirect_to root_path, alert: "Match not found"
    elsif @match.parse_replay!
      redirect_to @match, notice: "Replay parsed"
    else
      redirect_to @match, alert: @match.errors.full_messages.join(", ")
    end
  end

  def upload_replay
    if @match.nil?
      redirect_to root_path, alert: "Match not found"
    elsif @match.upload_replay(params[:replay])
      redirect_to @match, notice: "Replay uploaded"
    else
      redirect_to @match, alert: @match.errors.full_messages.join(", ")
    end
  end

  private

  def set_match
    @match = Match.includes(:competition, match_teams: :team).find_by(id: params[:id])
    @league = @match&.competition&.league
  end
end
