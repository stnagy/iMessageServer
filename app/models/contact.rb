class Contact < ApplicationRecord

  has_many :contact_messages
  has_many :messages, through: :contact_messages

end
