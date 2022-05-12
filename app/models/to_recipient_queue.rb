class ToRecipientQueue < ApplicationRecord

  belongs_to :message
  validates :sent, inclusion: { in: [ true, false ] }

  after_save :process_queue_item

  def process_queue_item

    if (self.sent == false)
      message = self.message
      message_body = message.message_text
      Message.process_message(message_body, "imessage")
      self.update(sent: true, sent_time: DateTime.now())
      return
    else
      return
    end
  end

end
