class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_debug_mode

  def set_debug_mode
    @debug_mode = cookies[:debug_mode] == "1"
  end

  def toggle_debug
    cookies[:debug_mode] = cookies[:debug_mode] == "1" ? "0" : "1"
    redirect_back fallback_location: root_path
  end
end
