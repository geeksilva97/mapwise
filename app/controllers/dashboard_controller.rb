class DashboardController < ApplicationController
  def index
    @maps = Maps::List.call(Current.user)
  end
end
