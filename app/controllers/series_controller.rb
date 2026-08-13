class SeriesController < ApplicationController
  def show
    @series = Series.includes(:league, competitions: [{ competition_teams: :team }, { matches: { match_teams: :team } }, { contests: [:home_team, :away_team] }], series_teams: :team).find_by(slug: params[:slug])
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

  def edit
    @series = Series.find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end

  def update
    @series = Series.find_by(slug: params[:slug])
    if @series.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    elsif @series.update(series_params)
      redirect_to @series, notice: "Series updated"
    else
      flash.now[:alert] = @series.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
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

  private

  def series_params
    params.require(:series).permit(:name, :length, :playoff_cutoff)
  end
end
