class ApplicationController < ActionController::Base

  def home
    @user = User.first
    render "home/index"
  end

  def update_preferences
    

  end
end
