class ApplicationController < ActionController::Base

  def home
    @user = User.first
    render "home/index"
  end

  def update_preferences
    @user = User.first
    user_prefs = @user.preferences
    user_prefs = user_prefs.merge(params[:user][:preferences].to_unsafe_h.deep_symbolize_keys)
    @user.update(preferences: user_prefs)
    @user.reload
    render json: @user.preferences
  end

  private

  def user_params
    params.require(:user).permit(:preferences => [:sms_forwarding_enabled, :phone_number, :iphone_number, :twilio_number, :twilio_account_id, :twilio_auth_token, :aws_id, :aws_secret, :aws_region, :sqs_url] )
  end

end
