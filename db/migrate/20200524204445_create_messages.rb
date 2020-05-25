class CreateMessages < ActiveRecord::Migration[6.0]
  def change

    create_table :messages do |t|
      t.text        :message_text
      t.boolean     :has_attachment
      t.text        :attachment_filetype
      t.boolean     :needs_sms_forwarding, default: false
      t.text        :twilio_message_id

      t.timestamps
    end

  end
end
