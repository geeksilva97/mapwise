class DashboardController < ApplicationController
  def index
    @maps = Current.user.maps.order(updated_at: :desc)
  end
end
