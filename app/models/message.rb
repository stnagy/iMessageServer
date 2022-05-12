class Message < ApplicationRecord

  has_many :contact_messages
  has_many :contacts, through: :contact_messages
  belongs_to :chat

  def sender
    Contact.find(self.contact_messages.where(is_sender: true).first.contact_id)
  end

  def other_recipients
    Contact.find(self.contact_messages.where(is_sender: false).pluck(:contact_id))
  end

  def is_group_chat?
    Contact.find(self.contact_messages.where(is_sender: false).pluck(:contact_id)).count > 1
  end

  def self.check_incoming_queues
    # Message.check_imessage_queue # <-- Don't need, handled by after_save callback on individual ToRecipientQueue record
    Message.check_twilio_sqs_queue
  end

  # function to check the SQS queue for new commands received by twilio
  def self.check_twilio_sqs_queue

    user_prefs = User.first.preferences

    # check to make sure required preferences are not nil.
    unless User.is_enabled?
      return false
    end

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

      # only forwarded number can access api
      if from_num == user_prefs[:phone_number]
        # refactor logic for message processing into separate method
        process_message(message_body, "twilio")
      end

      # delete sqs message when done
      resp = sqs.delete_message({
        queue_url: user_prefs[:sqs_url], #
        receipt_handle: receipt_handle,
      })
    end
  end

  # function to check the iMessage Queue for commands
  def self.check_imessage_queue

    user_prefs = User.first.preferences

    # get messages containing commands
    to_recipient_queues = ToRecipientQueue.where(sent: false).reverse

    to_recipient_queues.each do |queue_item|
      message = queue_item.message
      message_body = message.message_text
      process_message(message_body, "imessage")
      queue_item.update(sent: true, sent_time: DateTime.now())
    end
  end

  def self.process_message(message_body, respond_via="imessage")
    # supported commands are "forward" and "unforward" (for now)
    # beta support for replying with syntax "r {phone_number} {message}"
    user_prefs = User.first.preferences

    # map user shortcuts to regex for use below
    shortcut_regex = User.first.shortcuts.map { |s| /(^[rm]) (#{s.name}) (.+)/i }

    # forward command -- start forwarding imessages
    if message_body.downcase == "forward"
      updated_user_prefs = user_prefs.merge( {sms_forwarding_enabled: "true"} )
      User.first.update(preferences: updated_user_prefs)
      Message.send_quick_twilio_sms("iMessage forwarding started.") if respond_via == "twilio"
      Message.send_reply(user_prefs[:phone_number], "iMessage forwarding started.", false) if respond_via == "imessage"

    # unforward command -- stop forwarding imessages
    elsif message_body.downcase == "unforward"
      updated_user_prefs = user_prefs.merge( {sms_forwarding_enabled: "false"} )
      User.first.update(preferences: updated_user_prefs)
      Message.send_quick_twilio_sms("iMessage forwarding stopped.") if respond_via == "twilio"
      Message.send_reply(user_prefs[:phone_number], "iMessage forwarding stopped.", false) if respond_via == "imessage"

    # add shortcut command
    elsif command_match = message_body.match(/^(new shortcut) ([a-zA-z]+) (\d{10})/i)
      command, name, number = command_match.captures
      shortcut = User.first.shortcuts.new(name: name, number: number)
      shortcut.save
      if shortcut.errors.empty?
        Message.send_quick_twilio_sms("Shortcut created for #{name} (#{number}).") if respond_via == "twilio"
        Message.send_reply(user_prefs[:phone_number], "Shortcut created for #{name} (#{number}).", false) if respond_via == "imessage"
      else
        Message.send_quick_twilio_sms("Shorcut could not be created because of the following errors: #{shortcut.errors.full_messages}") if respond_via == "twilio"
        Message.send_reply(user_prefs[:phone_number], "Shorcut could not be created because of the following errors: #{shortcut.errors.full_messages}", false) if respond_via == "imessage"
      end

    # match user-defined shortcuts
    elsif shortcut_regex.any? { |pattern| pattern.match?(message_body) }
      shortcut_regex.each do |p|
        if shortcut_match = message_body.match(p)
          command, shortcut_name, body = shortcut_match.captures
          phone_number = User.first.shortcuts.find_by('lower(name) = ?', shortcut_name.downcase()).number
          unless Message.check_if_already_sent?(phone_number, body)
            Message.send_reply(phone_number, body)
            Message.send_quick_twilio_sms("Message delivered to #{phone_number}.") if respond_via == "twilio"
            Message.send_reply(User.first.preferences[:phone_number], "Message delivered to #{phone_number}.", false) if respond_via == "imessage"
          end
          break
        end
      end

    # match standard 9 and 10 digit phone numbers
    elsif message_body[0..13].downcase.match(/^[rm] \+\d{11}/)
      phone_number = message_body[2..13]
      body = message_body[15..]
      unless Message.check_if_already_sent?(phone_number, body)
        Message.send_reply(phone_number, body)
        Message.send_quick_twilio_sms("Message delivered to #{phone_number}.") if respond_via == "twilio"
        Message.send_reply(user_prefs[:phone_number], "Message delivered to #{phone_number}.", false) if respond_via == "imessage"
      end
    elsif message_body[0..12].downcase.match(/^[rm] \d{11}/)
      phone_number = "+" + message_body[2..12]
      body = message_body[14..]
      unless Message.check_if_already_sent?(phone_number, body)
        Message.send_reply(phone_number, body)
        Message.send_quick_twilio_sms("Message delivered to #{phone_number}.") if respond_via == "twilio"
        Message.send_reply(user_prefs[:phone_number], "Message delivered to #{phone_number}.", false) if respond_via == "imessage"
      end
    elsif message_body[0..12].downcase.match(/^[rm] \d{10}/)
      phone_number = "+1" + message_body[2..11]
      body = message_body[13..]
      unless Message.check_if_already_sent?(phone_number, body)
        Message.send_reply(phone_number, body)
        Message.send_quick_twilio_sms("Message delivered to #{phone_number}.") if respond_via == "twilio"
        Message.send_reply(user_prefs[:phone_number], "Message delivered to #{phone_number}.", false) if respond_via == "imessage"
      end

    # else, return an error message via text
    else
      Message.send_quick_twilio_sms("Command '#{message_body}' not recognized. Current commands supported are 'forward' and 'unforward' (no quotes) for starting and stopping iMessage forwarding.") if respond_via == "twilio"
      Message.send_reply(user_prefs[:phone_number], "Command '#{message_body}' not recognized. Current commands supported are 'forward' and 'unforward' (no quotes) for starting and stopping iMessage forwarding.", false) if respond_via == "imessage"
    end
  end

  # function to import imessages from iMessage chat database
  def self.import_messages(n=20)

    unless User.is_enabled?
      return false
    end

    message_tools = MessageTools.new
    messages = message_tools.get_messages(n)

    # update message fields
    messages.each do |m|
      message = Message.where(rowid: m["ROWID"]).first_or_initialize

      # only forward new messages
      # only forward messages if user wants to get them
      new_record = message.new_record?
      sms_forwarding_enabled = ( User.first.preferences[:sms_forwarding_enabled].to_s.downcase == "true" )

      chat = Chat.where(guid: m["chat_guid"]).first_or_create
      message.chat_id = chat.id
      message.save

      # update sender
      sender_name = m["sender_name"]
      sender_contact = m["sender_contact"]
      sender = Contact.where(contact_number: sender_contact).first_or_create
      sender.update(contact_name: sender_name)
      ContactMessage.where(contact_id: sender.id, message_id: message.id, is_sender: true).first_or_create

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
        twilio_message_id: nil
      )

      # create to_user_queue record for new incoming messages
      # 1. Don't forward the user's own messages (check each of iphone number, other phone number, OSX username)
      # 2. Only send messages if forwarding is enabled
      # 3. Only send new records
      if ( new_record && sms_forwarding_enabled && (sender_contact != User.first.preferences[:iphone_number]) && (sender_contact != User.first.preferences[:phone_number] ) && (sender_contact != User.first.preferences[:iphone_number] ) && (sender_name != `id -un`.gsub("\n","")))
        queue_item = ToUserQueue.where(message_id: message.id, sent: false).first_or_create
      end

      # create to_recipient_queue for new outgoing messages (user sends text to own iMessage account for forwarding to recipient)
      # 1. Must be from sender's other phone number
      # 2. Must be a new record (don't send multiple texts)
      # 3. Note, SMS forwarding enabled should not be required, otherwise SMS commands to forward/unforward cannot be made
      if ( new_record && ( sender_contact == User.first.preferences[:phone_number] ) )
        queue_item = ToRecipientQueue.where(message_id: message.id, sent: false).first_or_create
      end

    end
  end

  # function to send twilio SMS with a customizable message body
  def self.send_quick_twilio_sms(message_body)

    unless User.is_enabled?
      return false
    end

    account_sid = User.first.preferences[:twilio_account_id]
    auth_token = User.first.preferences[:twilio_auth_token]
    @client = Twilio::REST::Client.new(account_sid, auth_token)
    message = @client.messages.create( body: message_body, from: User.first.preferences[:twilio_number], to: User.first.preferences[:phone_number] )
  end

  # function to forward iMessages via twilio or SMS
  def self.forward_incoming_messages_to_user

    unless User.is_enabled?
      return false
    end

    # get message queues
    to_user_queues = ToUserQueue.where(sent: false).reverse

    # get user prefs
    user_prefs = User.first.preferences

    #iterate over messages (ordered by time received)
    to_user_queues.each do |queue_item|
      message = queue_item.message

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
      queue_item.update(sent: true, sent_time: DateTime.now())
    end
  end

  # function to return true if message already has been sent
  def self.check_if_already_sent?(phone_number, message_body)

    phone_number = phone_number.to_s[-10..]

    tools = MessageTools.new
    messages = tools.get_messages(10)

    messages.each do |m|
      recipients = m["other_recipients"]
      if (m["text"] == message_body)
        recipients.each do |r|
          if (r[:contact][-10..] == phone_number)
            return true
          end
        end
      end
    end

    return false
  end

  def self.send_reply(phone_number, message_body, send_as_imessage=true)

    phone_number = phone_number.to_s[-10..]

    # check recent messages to see if iMessage sent
    # if not, then send SMS
    tools = MessageTools.new
    messages = tools.get_messages(10)

    if send_as_imessage
      # try sending iMessage
      OsxTools.send_imessage(phone_number, message_body)

      # check recent messages to see if iMessage sent
      # if not, then send SMS
      tools = MessageTools.new
      messages = tools.get_messages(10)

      messages.each do |m|
        if (m["text"] == message_body)
          sleep 5
          if m["error"] != 0
            OsxTools.send_sms_message(phone_number, message_body)
            break
          end
        end
      end
    else
      OsxTools.send_sms_message(phone_number, message_body)
    end

    return

  end

end
