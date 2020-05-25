class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  serialize :preferences

  before_update :format_phone_numbers

  def format_phone_numbers

    unformatted_phone_number = self.preferences[:phone_number]
    raw_phone_number = unformatted_phone_number.scan(/\d/).join("")

    if raw_phone_number.length == 10
      formatted_phone_number = "+1" + raw_phone_number
    elsif raw_phone_number.length == 11
      formatted_phone_number = "+" + raw_phone_number
    else
      formatted_phone_number = raw_phone_number
    end

    self.preferences[:phone_number] = formatted_phone_number

    unformatted_twilio_number = self.preferences[:twilio_number]
    raw_twilio_number = unformatted_twilio_number.scan(/\d/).join("")

    if raw_twilio_number.length == 10
      formatted_twilio_number = "+1" + raw_twilio_number
    elsif raw_twilio_number.length == 11
      formatted_twilio_number = "+" + raw_twilio_number
    else
      formatted_twilio_number = raw_twilio_number
    end

    self.preferences[:twilio_number] = formatted_twilio_number

  end

end
