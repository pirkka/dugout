class SeriesController < ApplicationController
  def show
    @series = Series.includes(:league, competitions: :competition_teams, series_teams: :team).find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @series.league
    end
  end

  def create
    league = League.find_by(slug: params[:slug])
    if league.nil?
      redirect_to root_path, alert: "League not found"
    else
      series = league.series.create!(name: params[:series_name], slug: params[:series_name].parameterize)
      redirect_to series, notice: "Series created"
    end
  end

  def refresh
    @series = Series.find_by(slug: params[:slug])
    if @series.nil?
      redirect_to root_path, alert: "Series not found"
    else
      @series.calculate_standings
      redirect_back fallback_location: @series, notice: "Standings refreshed"
    end
  end
end
