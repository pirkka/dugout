class LeaguesController < ApplicationController

  def show
    @league = League.includes(:competitions).find_by(slug: params[:slug])
    if @league.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end

  def refresh
    @league = League.find_by(slug: params[:slug])
    if @league.nil?
      redirect_to root_path, alert: "League not found"
    elsif @league.refresh_from_api
      redirect_back fallback_location: @league, notice: "League refreshed"
    else
      redirect_back fallback_location: @league, alert: @league.errors.full_messages.join(", ")
    end
  end
end
