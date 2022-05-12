class ChatContact < ApplicationRecord

  belongs_to :chat
  belongs_to :contact

end
