class CoachesController < ApplicationController
  def show
    @coach = Coach.includes(:teams).find_by(slug: params[:slug])
    if @coach.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end
end
