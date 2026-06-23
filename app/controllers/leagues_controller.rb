class LeaguesController < ApplicationController

  def show
    @league = League.includes(:competitions).find_by(slug: params[:slug])
    if @league.nil?
      render file: "#{Rails.root}/public/404.html", status: :not_found
    end
  end
end
