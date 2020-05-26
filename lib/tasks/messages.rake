
namespace :messages do

  desc "import iMessages from OS X database"
  task :import => [:environment] do
    Message.import_messages
  end

  desc "send SMS messages via Twilio"
  task :send_sms => [:environment] do
    Message.send_twilio_sms
  end

end
