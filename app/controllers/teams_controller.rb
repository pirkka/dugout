class TeamsController < ApplicationController
  def show
    @team = Team.includes(:competitions).find_by(slug: params[:slug])
    if @team.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @team.competitions.first&.league
    end
  end
end
