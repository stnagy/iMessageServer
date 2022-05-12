class Chat < ApplicationRecord

  has_many :messages
  has_many :chat_contacts
  has_many :contacts, through: :messages

  #def self.group_chats
  #  Chat.all.reject { |chat| chat.contacts <= 2 }
  #end

end
