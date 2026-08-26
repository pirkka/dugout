class PlayersController < ApplicationController
  def show
    @player = Player.includes(:team, match_players: :match).find_by(id: params[:id])
    if @player.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @match_players = @player.match_players.newest_first
    end
  end
end
