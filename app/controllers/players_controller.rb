class PlayersController < ApplicationController
  def show
    @player = Player.includes(:team, match_players: :match).find_by(id: params[:id])
    if @player.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @match_players = @player.match_players.newest_first
      highlight_ids = @player.highlights.pluck(:id) + @player.injury_highlights.pluck(:id)
      @highlights = Highlight.where(id: highlight_ids).includes(:match_player, :injured_match_player, match: :teams).order("matches.started DESC, highlights.turn DESC")
    end
  end
end
