class Message < ApplicationRecord

  has_many :contact_messages
  has_many :contacts, through: :contact_messages

  def sender
    Contact.find(self.contact_messages.where(is_sender: true).first.contact_id)
  end

  def other_recipients
    Contact.find(self.contact_messages.where(is_sender: false).pluck(:contact_id))
  end

  def self.check_twilio_sqs_queue

    user_prefs = User.first.preferences

    sqs = Aws::SQS::Client.new(
      region: user_prefs[:aws_region],
      access_key_id: user_prefs[:aws_id],
      secret_access_key: user_prefs[:aws_secret]
    )

    response = sqs.receive_message({
      queue_url: user_prefs[:sqs_url],
      attribute_names: ["All"],
      max_number_of_messages: 10
      })

    response.messages.each do |m|
      m_hash = JSON.parse(m.body)
      receipt_handle = m.receipt_handle

      # message information from twilio
      account_sid = m_hash["AccountSid"]
      api_version = m_hash["ApiVersion"]
      from_city = m_hash["FromCity"]
      from_country = m_hash["FromCountry"]
      from_num = m_hash["From"]
      from_state = m_hash["FromState"]
      from_zip = m_hash["FromZip"]
      message_sid = m_hash["MessageSid"]
      message_body = m_hash["Body"]
      num_media = m_hash["NumMedia"]
      num_segments = m_hash["NumSegments"]
      sms_id = m_hash["SmsSid"]
      sms_status = m_hash["SmsStatus"]
      sms_message_sid = m_hash["SmsMessageSid"]
      to_city = m_hash["ToCity"]
      to_country = m_hash["ToCountry"]
      to_num = m_hash["To"]
      to_state = m_hash["ToState"]
      to_zip = m_hash["ToZip"]

      if message_body.downcase == "forward"
        updated_user_prefs = user_prefs.merge( {sms_forwarding_enabled: "true"} )
        User.first.update(preferences: updated_user_prefs)
        Message.send_quick_twilio_sms("iMessage forwarding started.")
      elsif message_body.downcase == "unforward"
        updated_user_prefs = user_prefs.merge( {sms_forwarding_enabled: "false"} )
        User.first.update(preferences: updated_user_prefs)
        Message.send_quick_twilio_sms("iMessage forwarding stopped.")
      else
        Message.send_quick_twilio_sms("Command '#{message_body}' not recognized. Current commands supported are 'forward' and 'unforward' (no quotes) for starting and stopping iMessage forwarding.")
      end

      resp = sqs.delete_message({
        queue_url: user_prefs[:sqs_url], #
        receipt_handle: receipt_handle,
      })
    end

  end

  def self.import_messages(n=20)
    message_tools = MessageTools.new
    messages = message_tools.get_messages(n)

    # update message fields
    messages.each do |m|
      message = Message.where(rowid: m["ROWID"]).first_or_initialize

      # only forward new messages
      # only forward messages if user wants to get them
      if message.new_record?
        needs_sms_forwarding = User.first.preferences[:sms_forwarding_enabled].to_s.downcase == "true"
      else
        needs_sms_forwarding = false
      end
      message.save

      # update sender
      sender_name = m["sender_name"]
      sender_contact = m["sender_contact"]
      sender = Contact.where(contact_number: sender_contact).first_or_create
      sender.update(contact_name: sender_name)
      ContactMessage.where(contact_id: sender.id, message_id: message.id, is_sender: true).first_or_create

      # do not forward iMessages where user responds from own iphone or OSX account
      if sender_contact == User.first.preferences[:iphone_number]
        needs_sms_forwarding = false
      elsif sender_name == `id -un`.gsub("\n","") # this gets the OSX username
        needs_sms_forwarding = false
      end

      # update other_recipients
      m["other_recipients"].each do |r|
        recipient_name = r[:name]
        recipient_contact = r[:contact]
        recipient = Contact.where(contact_number: recipient_contact).first_or_create
        recipient.update(contact_name: recipient_name)
        ContactMessage.where(contact_id: recipient.id, message_id: message.id, is_sender: false).first_or_create
      end

      message.update(
        message_text: m["text"],
        has_attachment: m["has_attachment"],
        attachment_filetype: m["attachment_filetype"],
        needs_sms_forwarding: needs_sms_forwarding,
        twilio_message_id: nil,
      )

    end
  end

  def self.send_quick_twilio_sms(message_body)
    account_sid = User.first.preferences[:twilio_account_id]
    auth_token = User.first.preferences[:twilio_auth_token]
    @client = Twilio::REST::Client.new(account_sid, auth_token)
    message = @client.messages.create( body: message_body, from: User.first.preferences[:twilio_number], to: User.first.preferences[:phone_number] )
  end

  def self.send_twilio_sms

    #initialize twilio client
    account_sid = User.first.preferences[:twilio_account_id]
    auth_token = User.first.preferences[:twilio_auth_token]
    @client = Twilio::REST::Client.new(account_sid, auth_token)

    #iterate over messages
    twilio_messages = Message.where(needs_sms_forwarding: true)
    twilio_messages.each do |m|

      # compose message body
      message_body =  "From: #{m.sender.contact_name} (#{m.sender.contact_number}) \n"
      if m.other_recipients.length > 0
        message_body += "CC: "
        message_body += m.other_recipients.map { |r| "#{r.contact_name} (#{r.contact_number})" }.join(", ")
        message_body += "\n***\n"
      end
      message_body += m.message_text

      # send message
      message = @client.messages.create( body: message_body, from: User.first.preferences[:twilio_number], to: User.first.preferences[:phone_number] )
      m.update(needs_sms_forwarding: false, twilio_message_id: message.sid)
    end
  end

end
