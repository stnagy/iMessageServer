class Contact < ApplicationRecord

  has_many :contact_messages
  has_many :messages, through: :contact_messages
  has_many :chat_contacts
  has_many :chats, through: :chat_contacts

end
