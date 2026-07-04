class LeaguesController < ApplicationController

  def show
    @league = League.includes(:competitions).find_by(slug: params[:slug])
    if @league.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end

  def new
    @league = League.new
  end

  def create
    @league = League.new(league_params.merge(platform: :pc, name: "temp", slug: "temp"))

    if @league.save
      if @league.refresh_from_api
        redirect_to @league, notice: "League created"
      else
        @league.destroy
        flash.now[:alert] = @league.errors.full_messages.join(", ")
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = @league.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
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

  private

  def league_params
    params.require(:league).permit(:game_version, :api_id)
  end
end
