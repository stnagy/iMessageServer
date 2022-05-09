class Shortcut < ApplicationRecord

  belongs_to :user

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :number, presence: true, format: { with: /\d{9,10}/,
    message: "Must be a 9-10 digit number" }

end
