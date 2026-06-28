class DugoutController < ApplicationController

  def index
    @leagues_by_letter = League.order(:name).group_by { |l| l.name[0].upcase }
  end
end
