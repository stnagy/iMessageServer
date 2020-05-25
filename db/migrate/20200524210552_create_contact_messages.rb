class CreateContactMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :contact_messages do |t|
      t.references  :contact, foreign_key: true
      t.references  :message, foreign_key: true
      t.boolean     :is_sender

      t.timestamps
    end
  end
end
