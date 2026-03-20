class DashboardController < ApplicationController
  def index
    @maps = Maps::List.call(Current.workspace)
  end
end
