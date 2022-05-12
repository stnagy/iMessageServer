
namespace :messages do

  desc "import iMessages from OS X database"
  task :import => [:environment] do
    Message.import_messages
  end

  desc "send SMS messages via Twilio"
  task :send_sms => [:environment] do
    Message.forward_incoming_messages_to_user
  end

  desc "check AWS SQS and iMessage for incoming commands"
  task :check_commands => [:environment] do
    Message.check_incoming_queues
  end

end
