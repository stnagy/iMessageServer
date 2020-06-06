class Chat < ApplicationRecord

  has_many :messages
  has_many :chat_contacts
  has_many :contacts, through: :chat_contacts
  
end
