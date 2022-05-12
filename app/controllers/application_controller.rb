class ApplicationController < ActionController::Base

  def chats
    @user = User.first
    render "home/chats"
  end

  def shortcuts
    @user = User.first
    @shortcut = {:name => ""}
    @shortcuts = @user.shortcuts
    render "home/shortcuts"
  end

  def settings
    @user = User.first
    render "home/settings"
  end

  def update_preferences
    @user = User.first
    user_prefs = @user.preferences
    user_prefs = user_prefs.merge(params[:user][:preferences].to_unsafe_h.deep_symbolize_keys)
    @user.update(preferences: user_prefs)
    @user.reload
    render json: @user.preferences
  end

  def add_shortcut
    print "controller"
    @shortcut = User.first.shortcuts.new(name: params[:shortcut][:name], number: params[:shortcut][:number].to_i)
    @shortcut.save
    if @shortcut.errors.empty?
      render json: @shortcut
    else
      render json: :error
      print @shortcut.errors.messages
    end
  end

  def delete_shortcut
    @shortcut = Shortcut.find(params[:shortcut][:id])
    @shortcut.destroy
    render :json => :deleted
  end

  private

  def user_params
    params.require(:user).permit(:preferences => [:sms_forwarding_enabled, :twilio_enabled, :imessage_enabled, :phone_number, :iphone_number, :twilio_number, :twilio_account_id, :twilio_auth_token, :aws_id, :aws_secret, :aws_region, :sqs_url] )
  end

end
