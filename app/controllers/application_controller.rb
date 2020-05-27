class ApplicationController < ActionController::Base

  def home
    @user = User.first
    render "home/index"
  end

  def update_preferences
    @user = User.first
    @user.update(preferences: params[:user][:preferences].to_unsafe_h.deep_symbolize_keys)
    @user.reload
    render json: @user.preferences
  end

  private

  def user_params
    params.require(:user).permit(:preferences => [:sms_forwarding_enabled, :phone_number, :iphone_number, :twilio_number, :twilio_account_id, :twilio_auth_token] )
  end

end
