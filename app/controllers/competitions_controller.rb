class CompetitionsController < ApplicationController
  def show
    @competition = Competition.includes(:league, :teams, :competition_teams, matches: { match_teams: :team }).find_by(slug: params[:slug])
    if @competition.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    else
      @league = @competition.league
      @series_list = @league.series
    end
  end

  def refresh
    @competition = Competition.find_by(slug: params[:slug])
    if @competition.nil?
      redirect_to root_path, alert: "Competition not found"
    elsif @competition.refresh_teams && @competition.refresh_matches && @competition.refresh_standings
      redirect_back fallback_location: @competition, notice: "Competition refreshed"
    else
      redirect_back fallback_location: @competition, alert: "Refresh failed"
    end
  end

  def add_to_series
    @competition = Competition.find_by(slug: params[:slug])
    if @competition.nil?
      redirect_to root_path, alert: "Competition not found"
    elsif params[:new_series_name].present?
      name = params[:new_series_name].strip
      if name.blank?
        redirect_back fallback_location: @competition, alert: "Series name cannot be blank"
      else
        series = @competition.league.series.create!(name: name, slug: name.parameterize)
        @competition.update!(series: series)
        redirect_back fallback_location: @competition, notice: "Created and added to series \"#{series.name}\""
      end
    elsif params[:series_id].present?
      series = Series.find_by(id: params[:series_id])
      if series.nil?
        redirect_back fallback_location: @competition, alert: "Series not found"
      else
        @competition.update!(series: series)
        redirect_back fallback_location: @competition, notice: "Added to series \"#{series.name}\""
      end
    else
      redirect_back fallback_location: @competition, alert: "No series selected"
    end
  end
end
