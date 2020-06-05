namespace :setup do

  desc "create user and assign preferences"
  task :install => [:environment] do

    # install dependencies and migrate database
    puts ""
    puts "Installing required ruby gems..."
    `bundle install`

    puts "Initializing databse... "
    `rake db:migrate`

    preferences = {
      sms_forwarding_enabled: "false",
    }

    user = User.first_or_create
    user_prefs = User.first.preferences
    preferences = user_prefs.merge(preferences)

    user.update(preferences: preferences)

    puts "Updating cron jobs..."
    `whenever --update-crontab --set environment='development'`

    puts "Starting web server..."
    `rails s -d`


    puts ""
    puts "*********************************"
    puts ""
    puts "iMessageServer application setup complete. For application to forward iMessages, you must visit the web interface to enter required settings. The application will not forward iMessages until all required settings are entered. "
    puts ""
    puts "To view and change application settings on the web interface, visit http://localhost:3000. Note, the web server does not need to be running for the application to forward iMessages. If web server is stopped, you may restart it by navigating to this folder and running the command `rails s -d`."
    puts ""
    puts "iMessage forwarding by default is DISABLED. To enable and disable it, you may text the word `forward` and `unforward` to your Twilio number (assigned by Twilio) from the phone where you wish to receive the forwarded iMessages. You may also enable forwarding on the web interface."
    puts ""
    puts "NOTE, YOUR COMPUTER MUST BE AWAKE TO FORWARD IMESSAGES."
    puts "On OS X, change energy saver preferences to check 'Prevent computer from sleeping automatically when the display is off' and uncheck 'Put hard disks to sleep when possible'."
    puts ""
    puts "*********************************"
    puts ""
  end

end
