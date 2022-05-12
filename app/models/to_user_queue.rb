class ToUserQueue < ApplicationRecord

  belongs_to :message
  validates :sent, inclusion: { in: [ true, false ] }

  after_save :process_queue_item

  def process_queue_item
    if (self.sent == false)

      user_prefs = User.first.preferences

      message = self.message

      # compose message body
      message_body =  "From: #{message.sender.contact_name} (#{message.sender.contact_number}) \n"
      if message.other_recipients.length > 0
        message_body += "CC: "
        message_body += message.other_recipients.map { |r| "#{r.contact_name} (#{r.contact_number})" }.join(", ")
        message_body += "\n***\n"
      end
      message_body += message.message_text

      if user_prefs[:twilio_enabled].to_s.downcase == "true"

        #initialize twilio client
        account_sid = User.first.preferences[:twilio_account_id]
        auth_token = User.first.preferences[:twilio_auth_token]
        @client = Twilio::REST::Client.new(account_sid, auth_token)

        # send message
        twilio_message = @client.messages.create( body: message_body, from: User.first.preferences[:twilio_number], to: User.first.preferences[:phone_number] )
        message.update(twilio_mesage_id: twilio_message.sid)

      elsif user_prefs[:imessage_enabled].to_s.downcase == "true"

        # send iMessage message
        Message.send_reply(User.first.preferences[:phone_number], message_body, false)

      else

        print("Neither Twilio nor iMessage forwarding enabled")

      end

      # update records
      self.update(sent: true, sent_time: DateTime.now())

      return

    else
      return
    end

  end

end
